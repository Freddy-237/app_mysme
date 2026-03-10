import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/app/router.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/services/iap_service.dart';
import 'package:mysme/core/services/push_notification_service.dart';
import 'package:mysme/core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Global socket manager — keeps socket connected as long as user is authed.
// Listens for new_conversation / new_message at the app level so events are
// never missed regardless of which page the user is on.
// ---------------------------------------------------------------------------

/// Root widget — provides theme and go_router navigation.
class MystmeApp extends ConsumerStatefulWidget {
  const MystmeApp({super.key});

  @override
  ConsumerState<MystmeApp> createState() => _MystmeAppState();
}

class _MystmeAppState extends ConsumerState<MystmeApp>
    with WidgetsBindingObserver {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _deepLinkSub;
  String? _lastHandledUri;
  bool _socketInitialized = false;
  SocketService? _socketService;
  final List<void Function()> _globalSocketDisposers = [];
  Timer? _catchupTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    // Initialize In-App Purchases.
    ref.read(iapServiceProvider).init();
    // Load offline message queue from local storage.
    ref.read(offlineQueueProvider).load();
    // Wire push notification tap → navigate to chat.
    _setupPushDeepLink();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _socketInitialized) {
      // Reconnect socket if needed and refresh conversations.
      final socket = ref.read(socketServiceProvider);
      socket.reconnectIfNeeded();
      ref.read(conversationProvider.notifier).fetchAllSilently();
      _startCatchupRefreshWindow();
    }
  }

  /// Short burst of silent refreshes after reconnect/resume.
  /// This bridges cases where the backend emitted while this device socket
  /// was offline (`socketsInRoom=0`).
  void _startCatchupRefreshWindow() {
    _catchupTimer?.cancel();
    var ticks = 0;
    _catchupTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      ref.read(conversationProvider.notifier).fetchAllSilently();
      ticks += 1;
      if (ticks >= 3) {
        timer.cancel(); // ~30s catch-up window
      }
    });
  }

  // ── Global socket: connect once auth is ready ─────────────────────────────

  /// Called from [build] via ref.listen so we react to auth state changes.
  void _onAuthChanged(AuthState? prev, AuthState next) {
    if (next.isAuthenticated && !_socketInitialized) {
      _connectGlobalSocket();
    } else if (!next.isAuthenticated && _socketInitialized) {
      _disconnectGlobalSocket();
    }
  }

  Future<void> _connectGlobalSocket() async {
    _socketInitialized = true;
    final SocketService socket =
        _socketService ?? ref.read(socketServiceProvider);
    _socketService = socket;
    await socket.connect(apiBaseUrl);

    // Immediate sync right after socket connect.
    ref.read(conversationProvider.notifier).fetchAllSilently();
    _startCatchupRefreshWindow();

    // Listen for new conversations — refresh the conversations list.
    _globalSocketDisposers.add(
      socket.onNewConversation((_) {
        ref.read(conversationProvider.notifier).fetchAllSilently();
      }),
    );

    // Listen for new messages — update conversations list preview/unread.
    _globalSocketDisposers.add(
      socket.onNewMessage((data) {
        final conversationId =
            (data['conversation_id'] ?? data['conversationId'] ?? '') as String;
        if (conversationId.isEmpty) return;

        final senderId =
            (data['sender_id'] ?? data['senderId'] ?? '') as String;
        final content = (data['content'] ?? '') as String;
        final me = ref.read(authProvider).userId;
        final notifier = ref.read(conversationProvider.notifier);
        final known = ref.read(conversationProvider).conversations.any(
              (c) => c.id == conversationId,
            );

        if (known) {
          notifier.updateLastMessage(conversationId, content, senderId);
          if (senderId != me) {
            notifier.incrementUnread(conversationId);
          }
        } else {
          // Unknown conversation — fetch to discover it.
          notifier.fetchAllSilently();
        }
      }),
    );
  }

  void _disconnectGlobalSocket({SocketService? socketService}) {
    _socketInitialized = false;
    _catchupTimer?.cancel();
    _catchupTimer = null;
    for (final dispose in _globalSocketDisposers) {
      dispose();
    }
    _globalSocketDisposers.clear();
    final service = socketService ?? _socketService;
    service?.disconnect();
  }

  Future<void> _setupPushDeepLink() async {
    PushNotificationService.onNotificationTap = (data) {
      final conversationId = data['conversationId'] as String?;
      if (conversationId != null && conversationId.isNotEmpty) {
        appRouter.go('/chat/$conversationId');
      }
    };
    // Process any notification that launched the app while terminated.
    await PushNotificationService.setupInteractionHandlers();
  }

  Future<void> _initDeepLinks() async {
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (_) {}

    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (_) {},
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    final uriString = uri.toString();
    if (_lastHandledUri == uriString) return;

    String? conversationId;
    String? pseudo;
    String? target;

    if (uri.scheme == 'mystme') {
      if (uri.host == 'chat' && uri.pathSegments.isNotEmpty) {
        conversationId = uri.pathSegments.first;
      }
      pseudo = uri.queryParameters['pseudo'];
      target = uri.queryParameters['target'];
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host == 'mysme.link' &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'c') {
      final inviteCode = uri.pathSegments[1];
      final resolved = await _resolveInviteCode(inviteCode);
      conversationId = resolved['conversationId'];
      pseudo = resolved['pseudo'] ?? uri.queryParameters['pseudo'];
      target = resolved['target'] ?? uri.queryParameters['name'];
    }

    if (conversationId == null || conversationId.isEmpty) return;

    _lastHandledUri = uriString;
    final query = <String, String>{
      'conversationId': conversationId,
      if (pseudo != null && pseudo.isNotEmpty) 'pseudo': pseudo,
      if (target != null && target.isNotEmpty) 'target': target,
    };
    final qs = Uri(queryParameters: query).query;

    appRouter.go('/deeplink-welcome?$qs');
  }

  Future<Map<String, String?>> _resolveInviteCode(String inviteCode) async {
    try {
      final client = ref.read(httpClientProvider);
      if (!client.isReady) {
        await client.init();
      }

      final res = await client.post('/conversation/resolve-link', {
        'inviteCode': inviteCode,
      });

      return {
        'conversationId': res['conversationId'] as String?,
        'pseudo': res['anonymousPseudo'] as String?,
        'target': res['targetPseudo'] as String?,
      };
    } catch (_) {
      return {
        'conversationId': null,
        'pseudo': null,
        'target': null,
      };
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _catchupTimer?.cancel();
    _deepLinkSub?.cancel();
    _disconnectGlobalSocket();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state to connect/disconnect socket automatically.
    ref.listen<AuthState>(authProvider, _onAuthChanged);

    final themeMode = ref.watch(themeProvider);
    return MaterialApp.router(
      title: 'MystMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
