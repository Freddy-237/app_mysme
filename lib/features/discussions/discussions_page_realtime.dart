// ignore_for_file: invalid_use_of_protected_member

part of 'discussions_page.dart';

extension _DiscussionsPageRealtime on _DiscussionsPageState {
  void _startVisibleRefresh() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      _refreshVisibleConversations();
    });
  }

  void _refreshVisibleConversations() {
    if (!mounted) return;
    final notifier = ref.read(conversationProvider.notifier);
    if (_visibleConversationIds.isEmpty) {
      notifier.fetchAllSilently();
      return;
    }
    notifier.refreshMany(_visibleConversationIds);
  }

  Future<void> _setupRealtime() async {
    if (_realtimeSetup) return;
    _realtimeSetup = true;

    _socketDisposers.add(
      _socket.onMessageDeleted((data) {
        if (!mounted) return;
        final conversationId = (data['conversationId'] ?? '') as String;
        if (conversationId.isEmpty) return;
        ref.read(conversationProvider.notifier).refreshOne(conversationId);
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

  void _trackVisibleConversations(List<ConversationDto> chats) {
    _visibleConversationIds
      ..clear()
      ..addAll(chats.take(12).map((conversation) => conversation.id));
  }
}
