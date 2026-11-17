import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

/// A single discussion row with avatar, name, last message, time & unread dot.
class DiscussionItem extends StatelessWidget {
  const DiscussionItem({
    super.key,
    required this.title,
    required this.message,
    required this.time,
    this.unread = false,
    this.unreadCount = 0,
    this.avatarSeed = '',
    this.onTap,
  });

  final String title;
  final String message;
  final String time;
  final bool unread;
  final int unreadCount;
  final String avatarSeed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Avatar
                avatarSeed.isNotEmpty
                    ? SeedAvatar(seed: avatarSeed, size: 52)
                    : const CircleAvatar(
                        radius: 26,
                        backgroundColor: AppColors.surfaceVariant,
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.textDisabled,
                          size: 28,
                        ),
                      ),
                const SizedBox(width: 14),

                // Name + message
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w500,
                          color: unread
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message,
                        style: TextStyle(
                          fontSize: 14,
                          color: unread
                              ? AppColors.textPrimary
                              : AppColors.textDisabled,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Time + unread dot
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            unread ? FontWeight.w700 : FontWeight.normal,
                        color: unread
                            ? AppColors.primaryStart
                            : AppColors.textDisabled,
                      ),
                    ),
                    if (unread) ...[
                      const SizedBox(height: 6),
                      unreadCount > 1
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryStart,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primaryStart,
                              ),
                            ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(left: 82),
            color: AppColors.divider,
          ),
        ],
      ),
    );
  }
}
