import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/home/widgets/custom_bottom_nav.dart';
import 'package:mysme/features/home/widgets/link_card.dart';
import 'package:mysme/features/home/widgets/share_card.dart';
import 'package:mysme/features/home/widgets/share_with.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

part 'home_screen_sections.dart';

/// Home screen with gradient header, share/link cards & animated bottom nav.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  late MotionTabBarController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = MotionTabBarController(
      initialIndex: 0,
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildHeader(),
          _buildContent(),
        ],
      ),
      bottomNavigationBar: buildMotionTabBar(
        controller: _tabController,
        initialIndex: 0,
        onTap: (index) {
          if (index == 1) {
            context.go('/discussions');
          } else if (index == 2) {
            context.go('/settings');
          }
        },
      ),
    );
  }
}
