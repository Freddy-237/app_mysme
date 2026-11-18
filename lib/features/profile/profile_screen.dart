import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/core/utils/helpers.dart';
import 'package:mysme/features/transfer/transfer_dialog.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';
import 'package:mysme/shared/widgets/themed_icon_button.dart';

part 'profile_screen_sections.dart';
part 'profile_screen_dialogs.dart';
part 'profile_screen_widgets.dart';

/// Profile page — mockup-faithful card layout with extra features.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late TextEditingController _bioController;
  bool _isEditingBio = false;
  bool _bioInitialized = false;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final linkState = ref.watch(linkProvider);
    final userName = auth.pseudo ?? 'Inconnu';
    final avatarSeed = auth.avatarSeed ?? 'default';
    final activeLink = linkState.activeLink;
    final linkUrl =
        activeLink != null ? activeLink.shareUrl(userName) : 'mysme.link/...';
    final linkDisplay = activeLink?.displayLink ?? 'mysme.link/...';

    // One-time init of bio controller from auth state.
    if (!_bioInitialized && auth.bio != null) {
      _bioController.text = auth.bio!;
      _bioInitialized = true;
    }

    // Fetch link when auth is ready and link not yet loaded.
    if (auth.isAuthenticated && activeLink == null && !linkState.isLoading) {
      Future.microtask(() async {
        try {
          await ref.read(linkProvider.notifier).getOrCreateLink();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[ProfileScreen] getOrCreateLink failed: $e');
          }
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // ── Purple gradient background (bottom half) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryEnd, AppColors.primaryStart],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
            ),
          ),

          // ── Page content ──
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Title bar ──
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        ThemedIconButton(
                          icon: adaptiveBackIcon(context),
                          iconSize: 18,
                          onTap: () => Navigator.pop(context),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Profil',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryStart,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 42), // balance the back button
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // ── Profile card ──
                  _buildProfileCard(avatarSeed, userName, auth.bio ?? ''),
                  const SizedBox(height: 14),

                  // ── Stats cards (Anonymous + Owner) ──
                  _buildStatsRow(),
                  const SizedBox(height: 12),

                  // ── Extra features ──
                  _buildExtraSection(linkUrl, linkDisplay, userName),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
