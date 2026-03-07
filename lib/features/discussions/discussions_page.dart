import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/discussions/widgets/discussion_item.dart';
import 'package:mysme/features/discussions/widgets/tab_selector.dart';
import 'package:mysme/features/home/widgets/custom_bottom_nav.dart';

/// Discussions page — lists anonymous conversations with animated tabs.
class DiscussionsPage extends ConsumerStatefulWidget {
  const DiscussionsPage({super.key});

  @override
  ConsumerState<DiscussionsPage> createState() => _DiscussionsPageState();
}

class _DiscussionsPageState extends ConsumerState<DiscussionsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  late MotionTabBarController _tabController;
  bool _realtimeSetup = false;
  Timer? _pollTimer;
  final Set<String> _joinedRooms = <String>{};
  final List<void Function()> _socketDisposers = [];
  final Set<String> _typingConversations = <String>{};
  final Map<String, Timer> _typingTimers = <String, Timer>{};
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _socket = ref.read(socketServiceProvider);
    _tabController = MotionTabBarController(
      initialIndex: 1,
      length: 3,
      vsync: this,
    );
    // Fetch real conversations from backend.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(conversationProvider.notifier).fetchAll();
      _setupRealtime();
      _startPollingFallback();
    });
  }

  void _startPollingFallback() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.read(conversationProvider.notifier).fetchAllSilently();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      ref.read(conversationProvider.notifier).fetchAll();
    }
  }

  Future<void> _setupRealtime() async {
    if (_realtimeSetup) return;
    _realtimeSetup = true;

    // Socket connection + new_message / new_conversation listeners are now
    // managed globally in MystmeApp. Here we only add page-specific listeners
    // for typing indicators, message deleted, etc.
    _socketDisposers.add(
      _socket.onMessageDeleted((data) {
        if (!mounted) return;
        final conversationId = (data['conversationId'] ?? '') as String;
        if (conversationId.isEmpty) return;
        ref.read(conversationProvider.notifier).fetchAllSilently();
      }),
    );

    _socketDisposers.add(
      _socket.onTypingStart((data) {
        if (!mounted) return;
        final conversationId = (data['conversationId'] ?? '') as String;
        final userId = (data['userId'] ?? '') as String;
        final myId = ref.read(authProvider).userId;
        if (conversationId.isEmpty || userId == myId) return;

        _typingTimers[conversationId]?.cancel();
        _typingTimers[conversationId] = Timer(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() => _typingConversations.remove(conversationId));
          _typingTimers.remove(conversationId);
        });

        if (!mounted) return;
        setState(() => _typingConversations.add(conversationId));
      }),
    );

    _socketDisposers.add(
      _socket.onTypingStop((data) {
        if (!mounted) return;
        final conversationId = (data['conversationId'] ?? '') as String;
        final userId = (data['userId'] ?? '') as String;
        final myId = ref.read(authProvider).userId;
        if (conversationId.isEmpty || userId == myId) return;

        _typingTimers[conversationId]?.cancel();
        _typingTimers.remove(conversationId);
        if (!mounted) return;
        setState(() => _typingConversations.remove(conversationId));
      }),
    );
  }

  void _syncJoinedRooms(List<ConversationDto> conversations) {
    for (final conv in conversations) {
      if (_joinedRooms.add(conv.id)) {
        _socket.joinConversation(conv.id);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    for (final timer in _typingTimers.values) {
      timer.cancel();
    }

    for (final disposeListener in _socketDisposers) {
      disposeListener();
    }

    for (final room in _joinedRooms) {
      _socket.leaveConversation(room);
    }

    _tabController.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime ts) {
    final now = DateTime.now();
    final diff = now.difference(ts);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inHours < 1) return 'Il y a ${diff.inMinutes}min';
    if (diff.inDays == 0) {
      return '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Hier';
    return 'Il y a ${diff.inDays}j';
  }

  @override
  Widget build(BuildContext context) {
    final convState = ref.watch(conversationProvider);
    final auth = ref.watch(authProvider);
    final myId = auth.userId ?? '';

    // Split: Propriétaire = conversations where I'm the owner,
    // Anonyme = conversations where I'm the anonymous user.
    // Filter out archived/expired conversations.
    final allConvs = convState.conversations
        .where((c) => !c.isArchived && c.status != 'deleted')
        .toList();
    _syncJoinedRooms(allConvs);

    final anonymeChats = allConvs.where((c) => c.anonymousId == myId).toList();
    final ownerChats = allConvs.where((c) => c.ownerId == myId).toList();

    final chats = _selectedTab == 0 ? ownerChats : anonymeChats;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.only(top: 125),
            child: Column(
              children: [
                TabSelector(
                  selectedIndex: _selectedTab,
                  onTap: (index) => setState(() => _selectedTab = index),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: convState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: chats.isEmpty
                              ? const Center(
                                  child: Text(
                                    'Aucune conversation',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 14,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  key: ValueKey(_selectedTab),
                                  padding: EdgeInsets.zero,
                                  itemCount: chats.length,
                                  itemBuilder: (context, index) {
                                    final conv = chats[index];
                                    // The "peer" is the other participant.
                                    final peerId = conv.ownerId == myId
                                        ? (conv.anonymousId ?? '?')
                                        : conv.ownerId;
                                    final isTyping =
                                        _typingConversations.contains(conv.id);
                                    return DiscussionItem(
                                      title: conv.peerPseudo(myId),
                                      message: isTyping
                                          ? 'En train d\'écrire…'
                                          : (conv.lastMessage ??
                                              (conv.isExpired
                                                  ? 'Conversation expirée'
                                                  : 'Appuie pour discuter')),
                                      time: _timeLabel(conv.lastMessageAt ??
                                          conv.startedAt ??
                                          conv.createdAt),
                                      unread: conv.hasUnread,
                                      unreadCount: conv.unreadCount,
                                      avatarSeed: peerId,
                                      onTap: () {
                                        context.push('/chat/${conv.id}');
                                      },
                                    );
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildMotionTabBar(
        controller: _tabController,
        initialIndex: 1,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 2) {
            context.go('/settings');
          }
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 120,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStart, AppColors.primaryEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(80),
        ),
      ),
      padding: const EdgeInsets.only(top: 50, left: 24),
      child: const Align(
        alignment: Alignment.topLeft,
        child: Text(
          'DISCUSSIONS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}
