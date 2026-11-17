import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/app/router.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/services/push_notification_service.dart';
import 'package:mysme/core/services/transfer_service.dart';
import 'package:mysme/core/utils/helpers.dart';
import 'package:mysme/core/theme/app_theme.dart';

void _appLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class _InviteResolutionResult {
  const _InviteResolutionResult({
    this.data,
    this.sessionLost = false,
  });

  final Map<String, String?>? data;
  final bool sessionLost;
}

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
  static const _supportedLinkHosts = <String>{
    'mysme.link',
    'www.myst-me.com',
    'myst-me.com',
    // Links shared before the move to myst-me.com keep working.
    'mystme-pwa.vercel.app',
  };
  StreamSubscription<Uri>? _deepLinkSub;
  String? _lastHandledUri;
  bool _socketInitialized = false;
  bool _socketConnecting = false;
  int _socketConnectionAttempt = 0;
  SocketService? _socketService;
  final List<void Function()> _globalSocketDisposers = [];

  // PWA → app transfer: a code received before the identity is ready
  // (cold start from a deep link, Android install referrer) waits here.
  String? _pendingTransferCode;
  bool _claimingTransfer = false;
  bool _installReferrerChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks();
    // Load offline message queue from local storage and prune stale items.
    unawaited(() async {
      final queue = ref.read(offlineQueueProvider);
      await queue.load();
      await queue.pruneOld();
    }());
    // Wire push notification tap → navigate to chat.
    _setupPushDeepLink();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshSessionOnResume());
      unawaited(_claimPendingTransfer());
    }
    if (state == AppLifecycleState.resumed && _socketInitialized) {
      // Reconnect socket if needed and refresh first page once.
      final socket = ref.read(socketServiceProvider);
      socket.reconnectIfNeeded();
      ref.read(conversationProvider.notifier).fetchAllSilently();
    }
  }

  /// Keep the 30-day token sliding for active users and finish hydrating the
  /// profile if the app was started offline.
  Future<void> _refreshSessionOnResume() async {
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated) return;
    await ref.read(httpClientProvider).refreshSessionToken();
    if (auth.pseudo == null) {
      await ref.read(authProvider.notifier).refreshMe();
    }
  }

  // ── Global socket: connect once auth is ready ─────────────────────────────

  /// Called from [build] via ref.listen so we react to auth state changes.
  void _onAuthChanged(AuthState? prev, AuthState next) {
    if (next.isAuthenticated && !next.isLoading) {
      unawaited(_checkInstallReferrer());
      unawaited(_claimPendingTransfer());
    }
    // Session rejected by the server while the app was in use.
    if (next.sessionLost && !(prev?.sessionLost ?? false)) {
      appRouter.go('/session-recovery');
    }
    if (next.isAuthenticated && !_socketInitialized && !_socketConnecting) {
      unawaited(_connectGlobalSocket());
    } else if (!next.isAuthenticated &&
        (_socketInitialized || _socketConnecting)) {
      _disconnectGlobalSocket();
    }
  }

  Future<void> _connectGlobalSocket() async {
    if (_socketInitialized || _socketConnecting) return;

    _socketConnecting = true;
    final attempt = ++_socketConnectionAttempt;
    final SocketService socket =
        _socketService ?? ref.read(socketServiceProvider);
    _socketService = socket;
    try {
      await socket.connect(apiBaseUrl);
      final isStillCurrent = mounted &&
          attempt == _socketConnectionAttempt &&
          ref.read(authProvider).isAuthenticated;
      if (!isStillCurrent) {
        socket.disconnect();
        return;
      }

      _socketInitialized = true;

      // Immediate sync right after socket connect.
      unawaited(ref.read(conversationProvider.notifier).fetchAllSilently());

      // Listen for new conversations — refresh only the emitted conversation.
      _globalSocketDisposers.add(
        socket.onNewConversation((data) {
          final conversationId =
              (data['id'] ?? data['conversation_id'] ?? '') as String;
          final notifier = ref.read(conversationProvider.notifier);
          if (conversationId.isEmpty) {
            unawaited(notifier.fetchAllSilently());
            return;
          }
          unawaited(notifier.refreshOne(conversationId));
        }),
      );

      // Listen for new messages — update conversations list preview/unread.
      _globalSocketDisposers.add(
        socket.onNewMessage((data) {
          final conversationId = (data['conversation_id'] ??
              data['conversationId'] ??
              '') as String;
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
            unawaited(notifier.refreshOne(conversationId));
          }
        }),
      );
    } catch (error) {
      _appLog('[MystmeApp._connectGlobalSocket] ERROR: $error');
      socket.disconnect();
    } finally {
      if (attempt == _socketConnectionAttempt) {
        _socketConnecting = false;
      }
    }
  }

  void _disconnectGlobalSocket({SocketService? socketService}) {
    _socketConnectionAttempt++;
    _socketInitialized = false;
    _socketConnecting = false;
    for (final dispose in _globalSocketDisposers) {
      dispose();
    }
    _globalSocketDisposers.clear();
    final service = socketService ?? _socketService;
    service?.disconnect();
  }

  /// Android: pick up the transfer code the PWA put in the Play Store link.
  Future<void> _checkInstallReferrer() async {
    if (_installReferrerChecked) return;
    _installReferrerChecked = true;
    final code =
        await ref.read(transferServiceProvider).readInstallReferrerCodeOnce();
    if (code != null) {
      _pendingTransferCode = code;
      await _claimPendingTransfer();
    }
  }

  /// Claims the pending transfer once an app identity exists.
  Future<void> _claimPendingTransfer() async {
    final code = _pendingTransferCode;
    if (code == null || _claimingTransfer) return;
    final auth = ref.read(authProvider);
    if (!auth.isAuthenticated || auth.isLoading) return;

    _claimingTransfer = true;
    try {
      final result = await ref.read(transferServiceProvider).claim(code);
      _pendingTransferCode = null;
      await ref.read(conversationProvider.notifier).fetchAllSilently();
      final count = result.conversationIds.length;
      _showDeepLinkError(count <= 1
          ? 'Ta conversation web est maintenant dans l\'app.'
          : 'Tes $count conversations web sont maintenant dans l\'app.');
    } catch (error) {
      _appLog('[MystmeApp._claimPendingTransfer] ERROR: $error');
      final status = error is ApiException ? error.statusCode : 0;
      final rejectedByServer = status >= 400 && status < 500;
      if (!rejectedByServer) {
        return; // offline / server down: keep the code, retry on resume
      }
      _pendingTransferCode = null; // invalid / used / expired: do not loop
      _showDeepLinkError(Helpers.friendlyErrorMessage(
        error,
        fallback:
            'Impossible de récupérer ta conversation web. Utilise le code depuis ton profil.',
      ));
    } finally {
      _claimingTransfer = false;
    }
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
    } catch (e) {
      _appLog('[MystmeApp._initDeepLinks] ERROR: $e');
    }

    _deepLinkSub = _appLinks.uriLinkStream.listen(
      (uri) => _handleDeepLink(uri),
      onError: (error) => _appLog('[MystmeApp.uriLinkStream] ERROR: $error'),
    );
  }

  Future<void> _handleDeepLink(Uri uri) async {
    final uriString = uri.toString();
    if (_lastHandledUri == uriString) return;

    String? conversationId;
    String? pseudo;
    String? target;
    var resolutionFailed = false;
    var sessionRecoveryRequired = false;

    // mystme://transfer?code=ABCD-2345 — opened from the PWA.
    if (uri.scheme == 'mystme' && uri.host == 'transfer') {
      final code = TransferService.extractCode(uri.queryParameters['code']);
      if (code != null) {
        _pendingTransferCode = code;
        await _claimPendingTransfer();
      }
      return;
    }

    if (uri.scheme == 'mystme') {
      if (uri.host == 'chat' && uri.pathSegments.isNotEmpty) {
        conversationId = uri.pathSegments.first;
      }
      pseudo = uri.queryParameters['pseudo'];
      target = uri.queryParameters['target'];
    } else if ((uri.scheme == 'https' || uri.scheme == 'http') &&
        _supportedLinkHosts.contains(uri.host) &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments.first == 'c') {
      final inviteCode = uri.pathSegments[1];
      final resolved = await _resolveInviteCode(inviteCode);
      if (resolved.sessionLost) {
        sessionRecoveryRequired = true;
      } else if (resolved.data == null) {
        resolutionFailed = true;
      } else {
        conversationId = resolved.data!['conversationId'];
        pseudo = resolved.data!['pseudo'] ?? uri.queryParameters['pseudo'];
        target = resolved.data!['target'] ?? uri.queryParameters['name'];
      }
    }

    if (conversationId == null || conversationId.isEmpty) {
      if (sessionRecoveryRequired) {
        appRouter.go('/session-recovery');
        return;
      }
      if (resolutionFailed) {
        _showDeepLinkError('Lien MystMe invalide ou expiré');
      }
      return;
    }

    _lastHandledUri = uriString;
    final query = <String, String>{
      'conversationId': conversationId,
      if (pseudo != null && pseudo.isNotEmpty) 'pseudo': pseudo,
      if (target != null && target.isNotEmpty) 'target': target,
    };
    final qs = Uri(queryParameters: query).query;

    appRouter.go('/deeplink-welcome?$qs');
  }

  Future<_InviteResolutionResult> _resolveInviteCode(String inviteCode) async {
    try {
      final auth = ref.read(authProvider);
      if (auth.sessionLost) {
        return const _InviteResolutionResult(sessionLost: true);
      }

      final client = ref.read(httpClientProvider);
      if (!client.isReady) {
        await client.init();
      }

      final res = await client.post('/conversation/resolve-link', {
        'inviteCode': inviteCode,
      });

      return _InviteResolutionResult(
        data: {
          'conversationId': res['conversationId'] as String?,
          'pseudo': res['anonymousPseudo'] as String?,
          'target': res['targetPseudo'] as String?,
        },
      );
    } on SessionLostException catch (error) {
      _appLog('[MystmeApp._resolveInviteCode] session lost: $error');
      return const _InviteResolutionResult(sessionLost: true);
    } catch (error) {
      _appLog('[MystmeApp._resolveInviteCode] resolution failed: $error');
      return const _InviteResolutionResult();
    }
  }

  void _showDeepLinkError(String message) {
    final context = appRouter.routerDelegate.navigatorKey.currentContext;
    final messenger =
        context == null ? null : ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
