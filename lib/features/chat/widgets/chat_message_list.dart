import 'package:flutter/material.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/chat/widgets/chat_bubble.dart';

class ChatMessageList extends StatelessWidget {
  const ChatMessageList({
    super.key,
    required this.pagingController,
    required this.scrollController,
    required this.expired,
    required this.authUserId,
    required this.messageKeys,
    required this.highlightedMessageId,
    required this.onReplyTap,
    required this.onLongPress,
    required this.onOptionsTap,
  });

  final PagingController<int, MessageDto> pagingController;
  final ScrollController scrollController;
  final bool expired;
  final String authUserId;
  final Map<String, GlobalKey> messageKeys;
  final String? highlightedMessageId;
  final void Function(String? messageId) onReplyTap;
  final void Function(MessageDto message) onLongPress;
  final void Function(MessageDto message) onOptionsTap;

  @override
  Widget build(BuildContext context) {
    return PagingListener<int, MessageDto>(
      controller: pagingController,
      builder: (context, state, fetchNextPage) {
        final rawItems = state.items ?? const <MessageDto>[];
        final seen = <String>{};
        final allItems = <MessageDto>[];
        for (final message in rawItems) {
          if (seen.add(message.id)) allItems.add(message);
        }

        return PagedListView<int, MessageDto>(
          state: state,
          fetchNextPage: fetchNextPage,
          scrollController: scrollController,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          builderDelegate: PagedChildBuilderDelegate<MessageDto>(
            noItemsFoundIndicatorBuilder: (_) => Center(
              child: Text(
                expired ? 'Cette conversation a expire.' : 'Dites bonjour...',
                style: TextStyle(
                  color: expired
                      ? AppColors.textSecondary
                      : AppColors.textDisabled,
                  fontSize: 14,
                ),
              ),
            ),
            firstPageProgressIndicatorBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
            newPageProgressIndicatorBuilder: (_) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            itemBuilder: (context, message, index) {
              Widget? separator;
              final dateStr = _formatDate(message.createdAt);
              if (index == allItems.length - 1) {
                separator = _buildDateSeparator(dateStr);
              } else if (index + 1 < allItems.length) {
                final next = allItems[index + 1];
                final nextDateStr = _formatDate(next.createdAt);
                if (dateStr != nextDateStr) {
                  separator = _buildDateSeparator(dateStr);
                }
              }

              final messageKey =
                  messageKeys.putIfAbsent(message.id, GlobalKey.new);

              return Column(
                children: [
                  if (separator != null) separator,
                  Padding(
                    key: messageKey,
                    padding: const EdgeInsets.only(bottom: 16),
                    child: ChatBubble(
                      message: message.content,
                      isSelf: message.isSelf(authUserId),
                      isHighlighted: highlightedMessageId == message.id,
                      isRead: message.isRead,
                      timestamp: message.formattedTime,
                      mediaUrl: message.mediaUrl,
                      mediaType: message.mediaType,
                      replyToContent: message.replyToContent,
                      onReplyTap: message.replyToMessageId == null
                          ? null
                          : () => onReplyTap(message.replyToMessageId),
                      onLongPress: () => onLongPress(message),
                      onOptionsTap: () => onOptionsTap(message),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final msgDate = DateTime(dt.year, dt.month, dt.day);
    if (msgDate == today) return "Aujourd'hui";
    if (msgDate == today.subtract(const Duration(days: 1))) return 'Hier';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Widget _buildDateSeparator(String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primaryEnd.withOpacity(0.25),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: AppColors.primaryEnd.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }
}
