part of 'discussions_page.dart';

extension _DiscussionsPageSections on _DiscussionsPageState {
  void _ensureRelevantTabSelected({
    required List<ConversationDto> ownerChats,
    required List<ConversationDto> anonymeChats,
    required ConversationsState state,
  }) {
    if (state.isLoading || state.isLoadingMore) {
      return;
    }

    if (_selectedTab == 0 && ownerChats.isEmpty && anonymeChats.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedTab != 0) return;
        (this as dynamic).setState(() => _selectedTab = 1);
      });
      return;
    }

    if (_selectedTab == 1 && anonymeChats.isEmpty && ownerChats.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _selectedTab != 1) return;
        (this as dynamic).setState(() => _selectedTab = 0);
      });
    }
  }

  void _ensureCurrentTabHasData(
    List<ConversationDto> chats,
    ConversationsState state,
  ) {
    if (chats.isNotEmpty ||
        !state.hasMore ||
        state.isLoading ||
        state.isLoadingMore) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(conversationProvider.notifier).fetchMore();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      ref.read(conversationProvider.notifier).fetchMore();
    }
  }

  Widget _buildEmptyState({
    required ConversationsState state,
    required int ownerChatsCount,
    required int anonymeChatsCount,
  }) {
    if (state.isLoadingMore) {
      return const Center(child: CircularProgressIndicator());
    }

    final otherTabCount =
        _selectedTab == 0 ? anonymeChatsCount : ownerChatsCount;
    final otherTabLabel = _selectedTab == 0 ? 'Anonyme' : 'Propriétaire';

    if (otherTabCount > 0) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.swap_horiz_rounded,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                '$otherTabCount conversation${otherTabCount > 1 ? 's' : ''} disponible${otherTabCount > 1 ? 's' : ''} dans l\'onglet $otherTabLabel',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => (this as dynamic)
                    .setState(() => _selectedTab = _selectedTab == 0 ? 1 : 0),
                child: Text('Voir $otherTabLabel'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.hasMore) {
      return Center(
        child: Text(
          'Recherche d\'autres conversations…',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
        ),
      );
    }

    return const Center(
      child: Text(
        'Aucune conversation',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(ConversationsState state) {
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (!state.hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: TextButton(
          onPressed: () => ref.read(conversationProvider.notifier).fetchMore(),
          child: const Text('Charger plus'),
        ),
      ),
    );
  }

  Widget _buildRefreshWarning(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFC067)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 18, color: Color(0xFFB76A00)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF7A4A00),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
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
