import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:motion_tab_bar/MotionTabBarController.dart';
import 'package:mysme/core/config/monetization.dart';
import 'package:mysme/core/providers/auth_provider.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/providers/link_provider.dart';
import 'package:mysme/core/providers/socket_service.dart';
import 'package:mysme/core/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/core/utils/helpers.dart';
import 'package:mysme/features/home/widgets/custom_bottom_nav.dart';
import 'package:mysme/features/settings/privacy_policy.dart';

part 'settings_page_actions.dart';
part 'settings_page_sections.dart';
part 'settings_page_widgets.dart';

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
  bool _isDeletingAccount = false;

  void _setDeletingAccount(bool value) {
    if (!mounted) return;
    setState(() => _isDeletingAccount = value);
  }

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
      Helpers.showErrorSnack(
        context,
        error,
        fallback:
            'Impossible de mettre à jour les notifications pour le moment.',
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

                  if (kPremiumPaymentsEnabled) ...[
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
                  ],

                  // ── Card 3: Contact Support + Conditions ──
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.help_outline_rounded,
                        label: 'Contacter le support',
                        onTap: _openSupport,
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.article_outlined,
                        label: "Conditions d'utilisation",
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryStart,
                        ),
                        onTap: _openTerms,
                      ),
                      const _TileDivider(),
                      _SettingsTile(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Politique de confidentialité',
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primaryStart,
                        ),
                        onTap: () => showPrivacyPolicy(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ── Card 4: Danger zone ──
                  _SettingsCard(
                    children: [
                      _SettingsTile(
                        icon: Icons.delete_forever_outlined,
                        label: 'Supprimer mon compte',
                        color: AppColors.error,
                        trailing: _isDeletingAccount
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null,
                        onTap:
                            _isDeletingAccount ? null : _confirmDeleteAccount,
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
}
