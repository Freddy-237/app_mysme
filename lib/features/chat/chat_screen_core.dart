// ignore_for_file: invalid_use_of_protected_member

part of 'chat_screen.dart';

extension _ChatScreenCore on _ChatScreenState {
  Future<void> _loadConversation() async {
    if (_conversationLoadFailed && mounted) {
      setState(() => _conversationLoadFailed = false);
    }

    try {
      final repo = ref.read(conversationRepositoryProvider);
      final conv = await repo.getConversation(_conversationId!);
      if (!mounted) return;
      setState(() {
        _conversation = conv;
        _conversationLoadFailed = false;
        _expired = kConversationExpiryEnabled && conv.isExpired;
        _remaining = conv.remainingTime;
      });
      _startCountdown();
      await _setupSocket();
      await _syncOpenConversationReadState();
    } catch (e) {
      if (!mounted) return;
      if (_conversation == null) {
        setState(() => _conversationLoadFailed = true);
        return;
      }
      if (!_socketSetup) {
        _showSocketRetrySnack(e);
        return;
      }
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible d\'ouvrir cette discussion pour le moment.',
      );
    }
  }

  Future<void> _setupSocket() async {
    if (_socketSetup) return;

    final socket = ref.read(socketServiceProvider);
    _socketService = socket;
    try {
      await socket.connect(apiBaseUrl);
      if (!mounted) return;
      _disposeSocketListeners();

      socket.joinConversation(_conversationId!);

      _socketDisposers.add(socket.onNewMessage((data) {
        if (!mounted) return;
        final msg = MessageDto.fromJson(data);
        if (msg.conversationId != _conversationId) return;
        _stageRealtimeMessage(msg);
        final myId = ref.read(authProvider).userId ?? '';
        if (msg.senderId != myId) {
          unawaited(_syncOpenConversationReadState());
        }
        _scrollToBottom();
      }));

      _socketDisposers.add(socket.onMessageDeleted((data) {
        if (!mounted) return;
        final id = (data['messageId'] ?? data['id'] ?? '') as String;
        if (id.isEmpty) return;
        _stageRemovedMessage(id);
      }));

      _socketDisposers.add(socket.onTypingStart((data) {
        if (!mounted) return;
        final cid = (data['conversationId'] ?? '') as String;
        if (cid != _conversationId) return;
        _typingTimer?.cancel();
        setState(() => _isTyping = true);
        _typingTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _isTyping = false);
        });
      }));

      _socketDisposers.add(socket.onTypingStop((data) {
        if (!mounted) return;
        final cid = (data['conversationId'] ?? '') as String;
        if (cid != _conversationId) return;
        _typingTimer?.cancel();
        setState(() => _isTyping = false);
      }));

      _socketDisposers.add(socket.onMessagesRead((data) {
        if (!mounted) return;
        final cid = (data['conversationId'] ?? '') as String;
        final readerId = (data['userId'] ?? '') as String;
        final myId = ref.read(authProvider).userId ?? '';
        if (cid != _conversationId || readerId.isEmpty || readerId == myId) {
          return;
        }
        _markMyMessagesAsRead();
      }));

      final myId = ref.read(authProvider).userId ?? '';
      final conv = _conversation;
      final otherUserId = conv == null
          ? null
          : (myId == conv.ownerId ? conv.anonymousId : conv.ownerId);

      if (otherUserId != null && otherUserId.isNotEmpty) {
        _socketDisposers.add(socket.onUserOnline((data) {
          if (!mounted) return;
          final uid = (data['userId'] ?? '') as String;
          if (uid == otherUserId) setState(() => _isOtherOnline = true);
        }));

        _socketDisposers.add(socket.onUserOffline((data) {
          if (!mounted) return;
          final uid = (data['userId'] ?? '') as String;
          if (uid == otherUserId) setState(() => _isOtherOnline = false);
        }));

        _socketDisposers.add(socket.onPresenceResult((data) {
          if (!mounted) return;
          final uid = (data['userId'] ?? '') as String;
          final online = (data['online'] ?? false) as bool;
          if (uid == otherUserId) setState(() => _isOtherOnline = online);
        }));

        socket.checkPresence(otherUserId);
      }

      _socketSetup = true;
    } catch (_) {
      _socketSetup = false;
      _disposeSocketListeners();
      rethrow;
    }
  }

  void _showSocketRetrySnack(Object error) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            Helpers.friendlyErrorMessage(
              error,
              fallback: 'Connexion temps réel indisponible.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Réessayer',
            onPressed: () => unawaited(_retrySocketSetup()),
          ),
        ),
      );
  }

  Future<void> _retrySocketSetup() async {
    try {
      await _setupSocket();
      await _syncOpenConversationReadState();
    } catch (error) {
      if (!mounted) return;
      _showSocketRetrySnack(error);
    }
  }

  void _disposeSocketListeners() {
    for (final disposeListener in _socketDisposers) {
      disposeListener();
    }
    _socketDisposers.clear();
  }

  void _markMyMessagesAsRead() {
    _markOwnMessagesRead = true;
    _applyPagingOverlay();
  }

  Future<void> _syncOpenConversationReadState() async {
    final conversationId = _conversationId;
    if (conversationId == null || conversationId.isEmpty) return;

    ref.read(conversationProvider.notifier).clearUnread(conversationId);
    ref.read(socketServiceProvider).emitMarkRead(conversationId);
    await ref.read(conversationProvider.notifier).markAsRead(conversationId);
  }

  void _stageRealtimeMessage(MessageDto message) {
    _pendingRemovedMessageIds.remove(message.id);
    _pendingRealtimeMessages[message.id] = message;
    _applyPagingOverlay();
  }

  void _stageRemovedMessage(String messageId) {
    _pendingRealtimeMessages.remove(messageId);
    _pendingRemovedMessageIds.add(messageId);
    _applyPagingOverlay();
  }

  void _applyPagingOverlay() {
    if (_applyingPagingOverlay) return;

    final pages = _pagingController.value.pages;
    if (pages == null) return;

    final myId = ref.read(authProvider).userId ?? '';
    final stagedMessages = _pendingRealtimeMessages.values
        .where((message) => !_pendingRemovedMessageIds.contains(message.id))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final nextPages = <List<MessageDto>>[];
    final existingIds = <String>{};

    for (var pageIndex = 0; pageIndex < pages.length; pageIndex++) {
      final sourcePage = pages[pageIndex];
      final transformedPage = <MessageDto>[];

      if (pageIndex == 0) {
        for (final staged in stagedMessages) {
          if (existingIds.add(staged.id)) {
            transformedPage.add(_decorateMessageOverlay(staged, myId));
          }
        }
      }

      for (final message in sourcePage) {
        if (_pendingRemovedMessageIds.contains(message.id)) {
          continue;
        }
        if (!existingIds.add(message.id)) {
          continue;
        }
        final staged = _pendingRealtimeMessages[message.id];
        transformedPage.add(
          _decorateMessageOverlay(staged ?? message, myId),
        );
      }

      nextPages.add(transformedPage);
    }

    if (_samePagingMessages(pages, nextPages)) {
      return;
    }

    _applyingPagingOverlay = true;
    try {
      _pagingController.value = _pagingController.value.copyWith(
        pages: nextPages,
      );
    } finally {
      _applyingPagingOverlay = false;
    }
  }

  MessageDto _decorateMessageOverlay(MessageDto message, String myId) {
    if (_markOwnMessagesRead && myId.isNotEmpty && message.senderId == myId) {
      return message.isRead ? message : message.copyWith(isRead: true);
    }
    return message;
  }

  bool _samePagingMessages(
    List<List<MessageDto>> current,
    List<List<MessageDto>> next,
  ) {
    if (current.length != next.length) return false;
    for (var pageIndex = 0; pageIndex < current.length; pageIndex++) {
      final currentPage = current[pageIndex];
      final nextPage = next[pageIndex];
      if (currentPage.length != nextPage.length) return false;
      for (var itemIndex = 0; itemIndex < currentPage.length; itemIndex++) {
        final a = currentPage[itemIndex];
        final b = nextPage[itemIndex];
        if (a.id != b.id ||
            a.isRead != b.isRead ||
            a.content != b.content ||
            a.mediaUrl != b.mediaUrl ||
            a.mediaType != b.mediaType ||
            a.replyToMessageId != b.replyToMessageId ||
            a.replyToContent != b.replyToContent ||
            a.replyToSenderId != b.replyToSenderId ||
            a.createdAt != b.createdAt ||
            a.isDeleted != b.isDeleted) {
          return false;
        }
      }
    }
    return true;
  }

  void _onInputChanged(String text) {
    if (_conversationId == null) return;
    final socket = ref.read(socketServiceProvider);
    if (text.isNotEmpty) {
      socket.emitTypingStart(_conversationId!);
      _localTypingTimer?.cancel();
      _localTypingTimer = Timer(const Duration(seconds: 3), () {
        socket.emitTypingStop(_conversationId!);
      });
    } else {
      _localTypingTimer?.cancel();
      socket.emitTypingStop(_conversationId!);
    }
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _jumpToOriginalMessage(String? messageId) {
    if (messageId == null || messageId.isEmpty) return;

    final key = _messageKeys[messageId];
    final targetContext = key?.currentContext;
    if (targetContext != null) {
      _highlightTimer?.cancel();
      if (mounted) setState(() => _highlightedMessageId = messageId);
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      _highlightTimer = Timer(const Duration(seconds: 1), () {
        if (mounted && _highlightedMessageId == messageId) {
          setState(() => _highlightedMessageId = null);
        }
      });
      return;
    }

    final loaded =
        _pagingController.items?.any((m) => m.id == messageId) ?? false;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          loaded
              ? 'Fais defiler pour voir le message original'
              : 'Message original non charge',
        ),
      ),
    );
  }

  void _startCountdown() {
    if (!kConversationExpiryEnabled) {
      _countdownTimer?.cancel();
      if (mounted) {
        setState(() {
          _expired = false;
          _remaining = const Duration(days: 36500);
        });
      }
      return;
    }
    _updateRemaining();
    _countdownTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _updateRemaining());
  }

  void _updateRemaining() {
    final conv = _conversation;
    if (conv == null) return;

    final remaining = conv.remainingTime;
    if (remaining == Duration.zero) {
      _countdownTimer?.cancel();
      setState(() {
        _remaining = Duration.zero;
        _expired = true;
      });
    } else {
      setState(() => _remaining = remaining);
    }
  }

  String _formatRemaining() {
    if (!kConversationExpiryEnabled) return 'Illimité';
    if (_remaining.inDays > 0) return '-${_remaining.inDays}j';
    if (_remaining.inHours > 0) return '-${_remaining.inHours}h';
    if (_remaining.inMinutes > 0) return '-${_remaining.inMinutes}min';
    if (_remaining.inSeconds > 0) return '-${_remaining.inSeconds}s';
    return '0';
  }

  Future<void> _handleSingleUnlock() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cette option est indisponible pendant le lancement.'),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty ||
        _expired ||
        _conversationId == null ||
        _isSending ||
        _isSendCoolingDown) {
      return;
    }

    final now = DateTime.now();
    final guardError = ChatSendGuard.validate(
      rawText: text,
      now: now,
      lastSentAt: _lastSentAt,
      lastSentContent: _lastSentContent,
    );
    if (guardError != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(guardError)));
      return;
    }

    final replyTarget = _replyTo;

    setState(() => _isSending = true);
    _input.clear();
    _scrollToBottom();

    try {
      await ref.read(messageRepositoryProvider).sendMessage(
            _conversationId!,
            text,
            replyToMessageId: replyTarget?.id,
          );
      if (!mounted) return;
      setState(() {
        _replyTo = null;
        _lastSentAt = now;
        _lastSentContent = text;
      });
      _armSendCooldown();
    } catch (e) {
      if (!mounted) return;

      if (isOfflineSendError(e)) {
        try {
          await ref.read(offlineQueueProvider).enqueue(PendingMessage(
                conversationId: _conversationId!,
                content: text,
                replyToMessageId: replyTarget?.id,
                queuedAt: DateTime.now(),
              ));
          if (!mounted) return;
          setState(() => _replyTo = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Hors ligne: message en file d\'attente'),
            ),
          );
        } catch (queueError) {
          _input.text = text;
          Helpers.showErrorSnack(
            context,
            queueError,
            fallback:
                'Connexion perdue. Le message n\'a pas pu être mis en attente.',
          );
        }
      } else if (e is ApiException &&
          e.statusCode == 403 &&
          e.message.toLowerCase().contains('bloqu')) {
        // The other participant blocked the conversation: refresh it so the
        // input bar gives way to the "blocked" banner.
        _input.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cette discussion a été bloquée.')),
        );
        await _loadConversation();
      } else {
        _input.text = text;
        Helpers.showErrorSnack(
          context,
          e,
          fallback: 'Impossible d\'envoyer le message pour le moment.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _armSendCooldown() {
    _sendCooldownTimer?.cancel();
    setState(() => _isSendCoolingDown = true);
    _sendCooldownTimer = Timer(ChatSendGuard.minInterval, () {
      if (mounted) setState(() => _isSendCoolingDown = false);
    });
  }

  String _replyPreview(MessageDto msg) {
    final raw = msg.content.trim();
    if (raw.isEmpty) return 'Message';
    const limit = 40;
    if (raw.length <= limit) return raw;
    return '${raw.substring(0, limit)}...';
  }

  void _startReply(MessageDto msg) {
    if (!mounted) return;
    setState(() => _replyTo = msg);
    _inputFocus.requestFocus();
  }

  void _removeMessageLocally(String messageId) {
    _stageRemovedMessage(messageId);
    if (_replyTo?.id == messageId) setState(() => _replyTo = null);
  }

  void _restoreMessageLocally(MessageDto msg) {
    _stageRealtimeMessage(msg);
  }

  Future<void> _hideMessageForMe(MessageDto msg) async {
    _removeMessageLocally(msg.id);
    try {
      await ref.read(messageRepositoryProvider).hideMessageForMe(msg.id);
    } catch (e) {
      _restoreMessageLocally(msg);
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible de masquer ce message pour le moment.',
      );
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Message masque'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Annuler', onPressed: () {}),
          ),
        )
        .closed;

    if (reason == SnackBarClosedReason.action) {
      try {
        await ref.read(messageRepositoryProvider).unhideMessageForMe(msg.id);
        if (mounted) _restoreMessageLocally(msg);
      } catch (e) {
        if (!mounted) return;
        Helpers.showErrorSnack(
          context,
          e,
          fallback: 'Impossible de restaurer ce message pour le moment.',
        );
      }
    }
  }

  Future<void> _deleteMessageForEveryone(MessageDto msg) async {
    try {
      await ref.read(messageRepositoryProvider).deleteMessage(msg.id);
      _removeMessageLocally(msg.id);
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible de supprimer ce message pour le moment.',
      );
    }
  }

  void _openMessageOptions(MessageDto msg) {
    final isSelf = msg.isSelf(ref.read(authProvider).userId ?? '');
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Repondre'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startReply(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.visibility_off_outlined),
                title: const Text('Masquer pour moi'),
                onTap: () {
                  Navigator.pop(ctx);
                  _hideMessageForMe(msg);
                },
              ),
              if (isSelf)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Supprimer pour tous'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _deleteMessageForEveryone(msg);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBlock() async {
    final id = _conversationId;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Bloquer cette discussion ?'),
        content: const Text(
          'Plus personne ne pourra y écrire, ni toi ni ton correspondant. '
          'Les messages déjà échangés restent visibles. '
          'Tu peux aussi signaler la personne si elle te harcèle.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryEnd),
            child: const Text('Bloquer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final updated =
          await ref.read(conversationProvider.notifier).blockConversation(id);
      if (!mounted) return;
      setState(() {
        _conversation = updated;
        _replyTo = null;
      });
      _inputFocus.unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Discussion bloquée')),
      );
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible de bloquer cette discussion pour le moment.',
      );
    }
  }

  void _showMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      // Scrollable: with five actions the sheet no longer fits small screens.
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MenuButton(
                  label: 'Rechercher un message',
                  icon: Icons.search,
                  iconColor: AppColors.deepPurple,
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _showSearch = true);
                  },
                ),
                const SizedBox(height: 16),
                MenuButton(
                  label: 'Medias partages',
                  icon: Icons.photo_library_outlined,
                  iconColor: AppColors.deepPurple,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => MediaGalleryScreen(
                            conversationId: _conversationId!),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                MenuButton(
                  label: 'Supprimer cette discussion',
                  icon: Icons.delete_outline,
                  iconColor: AppColors.primaryEnd,
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (_conversationId == null) return;
                    try {
                      await ref
                          .read(conversationProvider.notifier)
                          .deleteConversation(_conversationId!);
                      if (mounted) Navigator.pop(context);
                    } catch (e) {
                      if (!mounted) return;
                      Helpers.showErrorSnack(
                        context,
                        e,
                        fallback:
                            'Impossible de supprimer cette discussion pour le moment.',
                      );
                    }
                  },
                ),
                if (!_isBlocked) ...[
                  const SizedBox(height: 12),
                  MenuButton(
                    label: 'Bloquer cette discussion',
                    icon: Icons.block,
                    iconColor: AppColors.primaryEnd,
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmBlock();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                MenuButton(
                  label: _hasReportedConversation
                      ? 'Deja signale'
                      : 'Signaler cet utilisateur',
                  icon: Icons.thumb_down_alt_outlined,
                  iconColor: AppColors.primaryEnd,
                  onTap: _hasReportedConversation
                      ? () {
                          Navigator.pop(ctx);
                        }
                      : () async {
                          Navigator.pop(ctx);
                          if (_conversationId == null) return;
                          try {
                            await ref.read(moderationRepositoryProvider).report(
                                  conversationId: _conversationId!,
                                  reason: 'user_report',
                                );
                            if (!mounted) return;
                            setState(() => _hasReportedConversation = true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Signalement envoye')),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            Helpers.showErrorSnack(
                              context,
                              e,
                              fallback:
                                  'Impossible d\'envoyer le signalement pour le moment.',
                            );
                          }
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
