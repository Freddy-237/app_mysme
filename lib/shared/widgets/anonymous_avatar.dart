import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/core/theme/app_text_styles.dart';

/// Circular anonymous avatar with gradient ring.
class AnonymousAvatar extends StatelessWidget {
  const AnonymousAvatar({
    super.key,
    this.label,
    this.radius = 24,
    this.showRing = true,
  });

  /// One or two characters shown inside the avatar.
  final String? label;
  final double radius;
  final bool showRing;

  @override
  Widget build(BuildContext context) {
    final Widget inner = Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceVariant,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label!,
              style: AppTextStyles.headingSmall.copyWith(
                fontSize: radius * 0.6,
              ),
            )
          : Icon(
              Icons.person_outline_rounded,
              size: radius,
              color: AppColors.textSecondary,
            ),
    );

    if (!showRing) return inner;

    return Container(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: inner,
    );
  }
}
