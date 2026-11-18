import 'package:flutter/material.dart';
import 'package:mysme/core/config/monetization.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Lock overlay used only when conversation expiry is enabled.
class ChatLockOverlay extends StatelessWidget {
  const ChatLockOverlay({
    super.key,
    this.onUnlock,
  });

  /// Called when the user taps the unlock action.
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
    if (!kConversationExpiryEnabled) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.black.withOpacity(0.15),
      child: Column(
        children: [
          // Transparent top zone — lets chat peek through
          const Spacer(flex: 2),

          // Lock card
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: AppColors.primaryEnd,
                  width: 2.5,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    size: 100,
                    color: AppColors.primaryEnd,
                  ),
                  const SizedBox(height: 30),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Cette conversation est temporairement indisponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryEnd,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 28),
                    child: Text(
                      'Le lancement actuel ne propose pas de déblocage payant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: onUnlock,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEnd,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Option indisponible',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
