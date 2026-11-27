import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/shared/widgets/themed_icon_button.dart';

/// Gradient header bar with back button, avatar, name, typing indicator,
/// countdown, and menu button — extracted from [ChatScreen].
class ChatHeader extends StatelessWidget {
  const ChatHeader({
    super.key,
    required this.topPadding,
    required this.peerPseudo,
    required this.isTyping,
    required this.isOnline,
    required this.formattedRemaining,
    required this.onBack,
    required this.onMenu,
  });

  final double topPadding;
  final String peerPseudo;
  final bool isTyping;
  final bool isOnline;
  final String formattedRemaining;
  final VoidCallback onBack;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = isTyping
        ? 'en train d\'écrire...'
        : isOnline
            ? 'En ligne'
            : 'Hors ligne';

    return Container(
      padding: EdgeInsets.only(
        top: topPadding + 10,
        bottom: 18,
        left: 16,
        right: 8,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.deepPurple, AppColors.primaryEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(
                  adaptiveBackIcon(context),
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Stack(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? const Color(0xFF4CAF50)
                            : Colors.white.withOpacity(0.4),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.deepPurple,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      peerPseudo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      secondaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(isTyping ? 0.95 : 0.78),
                        fontSize: 12.5,
                        fontWeight:
                            isTyping ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onMenu,
                icon:
                    const Icon(Icons.more_vert, color: Colors.white, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      color: Colors.white.withOpacity(0.92),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formattedRemaining,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
