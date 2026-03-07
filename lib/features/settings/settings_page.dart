import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/providers/providers.dart';
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
  bool _notificationsEnabled = true;

  static const _storage = FlutterSecureStorage();
  static const _notifKey = 'mystme_notifications_enabled';

  @override
  void initState() {
    super.initState();
    _tabController = MotionTabBarController(
      initialIndex: 2,
      length: 3,
      vsync: this,
    );
    _loadNotificationPref();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadNotificationPref() async {
    final val = await _storage.read(key: _notifKey);
    if (val != null && mounted) {
      setState(() => _notificationsEnabled = val == 'true');
    }
  }

  Future<void> _saveNotificationPref(bool value) async {
    setState(() => _notificationsEnabled = value);
    await _storage.write(key: _notifKey, value: value.toString());
  }

  @override
  Widget build(BuildContext context) {
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
                          value: _notificationsEnabled,
                          activeColor: AppColors.primaryStart,
                          onChanged: (v) => _saveNotificationPref(v),
                        ),
                      ),
                      const _TileDivider(),
                      Consumer(builder: (context, ref, _) {
                        final themeMode = ref.watch(themeProvider);
                        final isDark = themeMode == ThemeMode.dark;
                        return _SettingsTile(
                          icon: isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          label: 'Mode sombre',
                          trailing: Switch(
                            value: isDark,
                            activeColor: AppColors.primaryStart,
                            onChanged: (_) =>
                                ref.read(themeProvider.notifier).toggle(),
                          ),
                        );
                      }),
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
                  const SizedBox(height: 32),

                  // ── Deconnexion button ──
                  _DeconnexionButton(
                    onTap: () async {
                      await ref.read(authProvider.notifier).signOut();
                      if (!context.mounted) return;
                      context.go('/onboarding');
                    },
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

/// Red-outlined Deconnexion button at the bottom.
class _DeconnexionButton extends StatelessWidget {
  const _DeconnexionButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.redAccent.withAlpha(160),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.logout_rounded,
              color: Colors.redAccent.withAlpha(200),
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              'Deconnexion',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.redAccent.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
