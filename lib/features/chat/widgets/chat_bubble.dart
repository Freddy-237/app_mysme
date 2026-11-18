import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/chat/widgets/audio_player_widget.dart';
import 'package:mysme/features/chat/widgets/video_message_bubble.dart';

/// A single chat message bubble — matches MystMe mockup.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.isSelf,
    this.isHighlighted = false,
    this.isRead,
    this.onLongPress,
    this.onOptionsTap,
    this.showOptionsIcon = true,
    this.replyToContent,
    this.onReplyTap,
    this.timestamp,
    this.mediaUrl,
    this.mediaType,
  });

  final String message;
  final bool isSelf;
  final bool isHighlighted;
  final bool? isRead;
  final VoidCallback? onLongPress;
  final VoidCallback? onOptionsTap;
  final bool showOptionsIcon;
  final String? replyToContent;
  final VoidCallback? onReplyTap;
  final String? timestamp;
  final String? mediaUrl;
  final String? mediaType;

  String _replyPreview(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Message';
    const limit = 44;
    if (value.length <= limit) return value;
    return '${value.substring(0, limit)}…';
  }

  @override
  Widget build(BuildContext context) {
    final hasCaption = message.trim().isNotEmpty;
    final bubbleColor = isHighlighted
        ? (isSelf ? AppColors.deepPurple : const Color(0xFFE8D8FF))
        : (isSelf ? AppColors.primaryEnd : const Color(0xFFF0ECF5));

    return Align(
      alignment: isSelf ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isSelf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isSelf && showOptionsIcon)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: InkWell(
                      onTap: onOptionsTap,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                Flexible(
                  child: GestureDetector(
                    onLongPress: onLongPress,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isSelf ? 20 : 6),
                          bottomRight: Radius.circular(isSelf ? 6 : 20),
                        ),
                        boxShadow: isHighlighted
                            ? [
                                BoxShadow(
                                  color: AppColors.primaryEnd.withOpacity(0.28),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : null,
                      ),
                      child: mediaType == 'image' && mediaUrl != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 10, 10, 6),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      mediaUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '🖼️ Image indisponible',
                                          style: TextStyle(
                                            color: isSelf
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (hasCaption)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 8, 12, 12),
                                    child: Text(
                                      message,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w400,
                                        color: isSelf
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                              ],
                            )
                          : mediaType == 'video' && mediaUrl != null
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: VideoMessageBubble(
                                        url: mediaUrl!,
                                        isSelf: isSelf,
                                      ),
                                    ),
                                    if (hasCaption)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            12, 8, 12, 12),
                                        child: Text(
                                          message,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w400,
                                            color: isSelf
                                                ? Colors.white
                                                : AppColors.textPrimary,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                  ],
                                )
                              : mediaType == 'audio' && mediaUrl != null
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AudioPlayerWidget(
                                          url: mediaUrl!,
                                          isSelf: isSelf,
                                        ),
                                        if (hasCaption)
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(
                                                12, 8, 12, 12),
                                            child: Text(
                                              message,
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w400,
                                                color: isSelf
                                                    ? Colors.white
                                                    : AppColors.textPrimary,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                      ],
                                    )
                                  : Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (replyToContent != null &&
                                              replyToContent!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            GestureDetector(
                                              onTap: onReplyTap,
                                              child: Container(
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isSelf
                                                      ? Colors.white
                                                          .withOpacity(0.18)
                                                      : AppColors.primaryEnd
                                                          .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.reply_rounded,
                                                      size: 12,
                                                      color: isSelf
                                                          ? Colors.white
                                                          : AppColors
                                                              .textSecondary,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        _replyPreview(
                                                            replyToContent!),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isSelf
                                                              ? Colors.white
                                                              : AppColors
                                                                  .textSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Text(
                                            message,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                              color: isSelf
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                              height: 1.4,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                    ),
                  ),
                ),
                if (isSelf && showOptionsIcon)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: InkWell(
                      onTap: onOptionsTap,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.expand_more_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timestamp!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelf
                          ? AppColors.primaryEnd.withOpacity(0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                  if (isSelf) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead == true
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: isRead == true
                          ? AppColors.primaryEnd
                          : AppColors.textSecondary,
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
