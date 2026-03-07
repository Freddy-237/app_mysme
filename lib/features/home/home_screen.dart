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

  /// Violet gradient header with user pseudo & avatar.
  Widget _buildHeader() {
    final auth = ref.watch(authProvider);
    final pseudo = auth.pseudo ?? 'Anonyme';
    final seed = auth.avatarSeed ?? 'default';

    return Container(
      height: 196,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStart, AppColors.primaryEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(80),
        ),
      ),
      padding: const EdgeInsets.only(top: 54, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salut,',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pseudo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: SeedAvatar(seed: seed, size: 50),
          ),
        ],
      ),
    );
  }

  /// Scrollable content: share card + link card.
  Widget _buildContent() {
    return const Padding(
      padding: EdgeInsets.only(top: 152),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ShareCard(),
            SizedBox(height: 16),
            LinkCard(),
            SizedBox(height: 14),
            ShareWith(),
            SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
