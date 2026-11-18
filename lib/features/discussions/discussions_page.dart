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

part 'discussions_page_realtime.dart';
part 'discussions_page_sections.dart';

/// Discussions page — lists anonymous conversations with animated tabs.
class DiscussionsPage extends ConsumerStatefulWidget {
  const DiscussionsPage({super.key});

  @override
  ConsumerState<DiscussionsPage> createState() => _DiscussionsPageState();
}

class _DiscussionsPageState extends ConsumerState<DiscussionsPage>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTab = 0;
  final ScrollController _scrollController = ScrollController();
  final List<String> _visibleConversationIds = [];
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
    _scrollController.addListener(_onScroll);
    // Fetch real conversations from backend.
    Future.microtask(() {
      if (!mounted) return;
      ref.read(conversationProvider.notifier).fetchAll();
      _setupRealtime();
      _startVisibleRefresh();
    });
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

    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!mounted) return;
      _refreshVisibleConversations();
    }
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

    _ensureRelevantTabSelected(
      ownerChats: ownerChats,
      anonymeChats: anonymeChats,
      state: convState,
    );

    final chats = _selectedTab == 0 ? ownerChats : anonymeChats;
    _trackVisibleConversations(chats);
    _ensureCurrentTabHasData(chats, convState);

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
                if (convState.error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: _buildRefreshWarning(convState.error!),
                  ),
                const SizedBox(height: 16),
                Expanded(
                  child: convState.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: chats.isEmpty
                              ? _buildEmptyState(
                                  state: convState,
                                  ownerChatsCount: ownerChats.length,
                                  anonymeChatsCount: anonymeChats.length,
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  key: ValueKey(_selectedTab),
                                  padding: EdgeInsets.zero,
                                  itemCount: chats.length +
                                      ((convState.isLoadingMore ||
                                              convState.hasMore)
                                          ? 1
                                          : 0),
                                  itemBuilder: (context, index) {
                                    if (index >= chats.length) {
                                      return _buildPaginationFooter(convState);
                                    }
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
}
