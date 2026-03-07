import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Lock overlay shown when a conversation reaches 7 days.
/// Offers "Unlock discussion 2$" or "Pass Premium".
class ChatLockOverlay extends StatelessWidget {
  const ChatLockOverlay({
    super.key,
    this.onUnlock,
  });

  /// Called when the user taps "Unlock discussion".
  final VoidCallback? onUnlock;

  @override
  Widget build(BuildContext context) {
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
                  // Lock icon
                  const Icon(
                    Icons.lock_rounded,
                    size: 100,
                    color: AppColors.primaryEnd,
                  ),
                  const SizedBox(height: 30),

                  // Unlock button
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
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Unlock discusion',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '2\$',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // OR
                  const Text(
                    'OR',
                    style: TextStyle(
                      color: AppColors.primaryEnd,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Pass Premium button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          context.push('/paywall');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryEnd,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Pass Premium',
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
