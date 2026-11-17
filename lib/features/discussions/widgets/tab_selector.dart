import 'package:flutter/material.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Animated tab selector with underline indicator (Anonymous / Owner).
class TabSelector extends StatelessWidget {
  const TabSelector({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  final int selectedIndex;
  final Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTab('Propriétaire', 0),
          _buildTab('Anonyme', 1),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final bool isActive = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isActive ? AppColors.primaryStart : AppColors.textDisabled,
            ),
            child: Text(title),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 3,
            width: isActive ? 80 : 0,
            decoration: BoxDecoration(
              color: AppColors.primaryStart,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
