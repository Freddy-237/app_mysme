import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/providers/auth_provider.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/features/home/widgets/custom_bottom_nav.dart';

/// Settings page — matches the MystMe mockup with grouped cards.
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage>
    with TickerProviderStateMixin {
  late MotionTabBarController _tabController;
  bool _isSavingNotifications = false;

  @override
  void initState() {
    super.initState();
    _tabController = MotionTabBarController(
      initialIndex: 2,
      length: 3,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _saveNotificationPref(bool value) async {
    if (_isSavingNotifications) return;

    setState(() => _isSavingNotifications = true);
    try {
      await ref.read(authProvider.notifier).updateNotificationPreference(value);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Impossible de mettre à jour les notifications: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingNotifications = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // ── Card 1: My Profil + Notification ──
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.person_outline_rounded,
                        label: 'Mon Profil',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryStart,
                        ),
                        onTap: () => context.push('/profile'),
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        trailing: Switch(
                          value: authState.notificationsEnabled,
                          activeColor: AppColors.primaryStart,
                          onChanged: _isSavingNotifications
                              ? null
                              : (v) => _saveNotificationPref(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Card 2: Mysme Premium ──
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.star_outline_rounded,
                        label: 'Mysme Premium',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryStart,
                        ),
                        onTap: () => context.push('/paywall'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Card 3: Contact Support + Conditions ──
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Contact Support',
                        onTap: () {
                          // TODO: open support
                        },
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.article_outlined,
                        label: "Conditions d'utilisation",
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryStart,
                        ),
                        onTap: () {
                          // TODO: open terms
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: buildMotionTabBar(
        controller: _tabController,
        initialIndex: 2,
        onTap: (index) {
          if (index == 0) {
            context.go('/home');
          } else if (index == 1) {
            context.go('/discussions');
          }
        },
      ),
    );
  }

  /// Violet gradient header — same style as other pages.
  Widget _buildHeader() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStart, AppColors.primaryEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(80),
        ),
      ),
      padding: const EdgeInsets.only(top: 56, left: 24),
      child: const Align(
        alignment: Alignment.topLeft,
        child: Text(
          'SETTINGS',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Private sub-widgets
// ──────────────────────────────────────────────────────────────

/// A rounded card that groups several [_SettingsTile]s.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primaryStart.withAlpha(40),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// A single settings row with icon, label and optional trailing widget.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primaryStart, size: 26),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Thin divider used between tiles inside a card.
class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: AppColors.primaryStart.withAlpha(25),
      ),
    );
  }
}
