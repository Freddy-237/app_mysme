import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';

IconData adaptiveBackIcon(BuildContext context) {
  final platform = Theme.of(context).platform;
  if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
    return CupertinoIcons.back;
  }
  return Icons.arrow_back;
}

/// Circular icon button with a subtle glass surface that keeps contrast on
/// gradients, white backgrounds and transparent app bars.
class ThemedIconButton extends StatelessWidget {
  const ThemedIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.iconSize = 20,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        dark ? Colors.black.withOpacity(0.32) : Colors.white.withOpacity(0.88);
    final borderColor = dark
        ? Colors.white.withOpacity(0.16)
        : AppColors.primaryStart.withOpacity(0.14);
    final shadowColor = dark
        ? Colors.black.withOpacity(0.20)
        : AppColors.primaryStart.withOpacity(0.14);
    final iconColor = dark ? Colors.white : AppColors.primaryStart;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Icon(icon, size: iconSize, color: iconColor),
        ),
      ),
    );
  }
}
