import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Overlay displayed when the peer requests to see your identity.
class ChatIdentityRequestOverlay extends StatelessWidget {
  const ChatIdentityRequestOverlay({
    super.key,
    required this.requesterName,
    required this.onAccept,
    required this.onDismiss,
  });

  final String requesterName;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDismiss,
      child: Container(
        color: Colors.white.withOpacity(0.92),
        child: Column(
          children: [
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                '$requesterName requests to\nsee your identity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 64,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onAccept,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                        color: AppColors.primaryEnd, width: 2.5),
                    foregroundColor: AppColors.primaryEnd,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: const Text(
                    'ACCEPTED',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}
