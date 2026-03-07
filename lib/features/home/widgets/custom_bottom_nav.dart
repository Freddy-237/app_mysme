import 'package:flutter/material.dart';
import 'package:motion_tab_bar/MotionTabBar.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/theme/app_colors.dart';

/// Builds a MotionTabBar configured with MystMe theme colors.
/// Must be used inside a StatefulWidget with TickerProviderStateMixin
/// that provides a [MotionTabBarController].
MotionTabBar buildMotionTabBar({
  required MotionTabBarController controller,
  required int initialIndex,
  required void Function(int) onTap,
}) {
  return MotionTabBar(
    controller: controller,
    initialSelectedTab: ['HOME', 'DISCUSSIONS', 'SETTINGS'][initialIndex],
    labels: const ['HOME', 'DISCUSSIONS', 'SETTINGS'],
    icons: const [
      Icons.home_rounded,
      Icons.chat_bubble_outline_rounded,
      Icons.settings_outlined,
    ],
    tabSize: 50,
    tabBarHeight: 55,
    textStyle: const TextStyle(
      fontSize: 10,
      color: AppColors.primaryStart,
      fontWeight: FontWeight.w600,
    ),
    tabIconColor: AppColors.primaryStart,
    tabIconSize: 26,
    tabIconSelectedSize: 24,
    tabSelectedColor: AppColors.primaryStart,
    tabIconSelectedColor: Colors.white,
    tabBarColor: Colors.white,
    onTabItemSelected: onTap,
  );
}
