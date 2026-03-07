import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/core/theme/app_colors.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

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
      debugPrint(
          '[ProfileScreen] auth ready, no activeLink, triggering getOrCreateLink');
      Future.microtask(() async {
        try {
          await ref.read(linkProvider.notifier).getOrCreateLink();
          debugPrint('[ProfileScreen] getOrCreateLink completed OK');
        } catch (e) {
          debugPrint('[ProfileScreen] getOrCreateLink FAILED: $e');
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
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded,
                              size: 20),
                          onPressed: () => Navigator.pop(context),
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
                        const SizedBox(width: 48), // balance the back button
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

  /// White rounded card with avatar, name, bio and edit.
  Widget _buildProfileCard(
      String avatarSeed, String userName, String currentBio) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.primaryStart.withAlpha(50),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryStart.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Avatar + camera badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              SeedAvatar(seed: avatarSeed, size: 100),
              Positioned(
                bottom: 0,
                right: -4,
                child: GestureDetector(
                  onTap: () {
                    // TODO: change avatar / regenerate identity
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryStart.withAlpha(80),
                      ),
                    ),
                    child: const Icon(
                      Icons.camera_alt_outlined,
                      size: 16,
                      color: AppColors.primaryStart,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // User name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryStart,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 12),

          // Bio
          Align(
            alignment: Alignment.centerLeft,
            child: _isEditingBio
                ? TextField(
                    controller: _bioController,
                    maxLines: 3,
                    maxLength: 120,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Écris ta bio...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.primaryStart),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                            color: AppColors.primaryStart, width: 2),
                      ),
                    ),
                  )
                : Text(
                    currentBio,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
          ),
          const SizedBox(height: 6),

          // Modifier button
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                if (_isEditingBio) {
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .updateBio(_bioController.text);
                  } catch (_) {}
                  setState(() => _isEditingBio = false);
                } else {
                  setState(() => _isEditingBio = true);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isEditingBio ? Icons.check_rounded : Icons.edit_outlined,
                    size: 16,
                    color: AppColors.primaryStart,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isEditingBio ? 'Enregistrer' : 'Modifier',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryStart,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Two gradient stat cards side by side — Anonymous & Owner.
  Widget _buildStatsRow() {
    final auth = ref.watch(authProvider);
    final convState = ref.watch(conversationProvider);
    final myId = auth.userId;
    final convos = convState.conversations;

    final anonymousCount =
        convos.where((c) => c.anonymousId == myId).length.toString();
    final ownerCount = convos.where((c) => c.ownerId == myId).length.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.person_outline_rounded,
              badgeIcon: Icons.lock_outline_rounded,
              label: 'Anonymous',
              value: anonymousCount,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.person_rounded,
              label: 'Owner',
              value: ownerCount,
            ),
          ),
        ],
      ),
    );
  }

  /// Extra features section — link sharing, QR, regenerate identity.
  Widget _buildExtraSection(
      String linkUrl, String linkDisplay, String userName) {
    final auth = ref.watch(authProvider);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // ── Quick link copy ──
          _ExtraTile(
            icon: Icons.link_rounded,
            label: 'Copier mon lien',
            subtitle: linkDisplay.toUpperCase(),
            trailing:
                const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            onTap: () async {
              try {
                var finalLinkUrl = linkUrl;

                // If link is still a placeholder, fetch/create it before copying.
                if (finalLinkUrl.contains('...')) {
                  final link =
                      await ref.read(linkProvider.notifier).getOrCreateLink();
                  finalLinkUrl = link.shareUrl(userName);
                }

                await Clipboard.setData(ClipboardData(text: finalLinkUrl));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Lien copié !'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (_) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Impossible de générer le lien pour le moment'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 10),

          // ── QR Code ──
          _ExtraTile(
            icon: Icons.qr_code_rounded,
            label: 'Mon QR Code',
            subtitle: 'Partage ton profil en un scan',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: () {
              // TODO: show QR code bottom sheet
            },
          ),
          const SizedBox(height: 10),

          // ── Regenerate identity ──
          _ExtraTile(
            icon: Icons.refresh_rounded,
            label: 'Régénérer mon identité',
            subtitle: 'Nouveau pseudo & avatar',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: () {
              _showRegenerateDialog();
            },
          ),
          const SizedBox(height: 10),

          // ── Recovery key: save account ──
          _ExtraTile(
            icon: Icons.key_outlined,
            label: 'Sauvegarder mon compte',
            subtitle: 'Générer une clé de récupération',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showGenerateRecoveryKeyDialog,
          ),
          const SizedBox(height: 10),

          // ── Recovery key: restore account ──
          _ExtraTile(
            icon: Icons.restore_rounded,
            label: 'Restaurer mon compte',
            subtitle: 'Entrer une clé de récupération',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showRestoreRecoveryKeyDialog,
          ),
          const SizedBox(height: 10),

          // ── Optional OTP email linkage ──
          _ExtraTile(
            icon: Icons.alternate_email_rounded,
            label: 'Lier un email (OTP)',
            subtitle: auth.email == null
                ? 'Sécuriser la récupération multi-appareil'
                : 'Email lié: ${auth.email}${auth.isEmailVerified ? ' (vérifié)' : ''}',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showEmailOtpLinkDialog,
          ),
          const SizedBox(height: 10),

          // ── Account age ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(25),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    color: Colors.white.withAlpha(200), size: 18),
                const SizedBox(width: 10),
                Text(
                  'Anonyme depuis aujourd\'hui',
                  style: TextStyle(
                    color: Colors.white.withAlpha(200),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRegenerateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Régénérer ton identité ?'),
        content: const Text(
          'Tu obtiendras un nouveau pseudo et un nouvel avatar. '
          'Ton ancienne identité sera perdue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              // Generate new pseudo and sync with backend.
              final newPseudo =
                  'Anon_${DateTime.now().millisecondsSinceEpoch % 100000}';
              await ref.read(authProvider.notifier).updatePseudo(newPseudo);
            },
            child: const Text(
              'Régénérer',
              style: TextStyle(color: AppColors.primaryStart),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGenerateRecoveryKeyDialog() async {
    try {
      final key = await ref.read(authProvider.notifier).generateRecoveryKey();
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Clé de récupération'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conserve cette clé en lieu sûr. Elle permet de récupérer ton compte sur un autre appareil.',
              ),
              const SizedBox(height: 12),
              SelectableText(
                key,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryStart,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: key));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Clé copiée.')),
                );
              },
              child: const Text('Copier'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de générer la clé: $e')),
      );
    }
  }

  Future<void> _showRestoreRecoveryKeyDialog() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Restaurer le compte'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            hintText: 'XXXXX-XXXXX-XXXXX-XXXXX',
            labelText: 'Clé de récupération',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(authProvider.notifier).restoreWithRecoveryKey(key);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Compte restauré avec succès.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Restauration impossible: $e')),
                );
              }
            },
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    controller.dispose();
  }

  Future<void> _showEmailOtpLinkDialog() async {
    final emailController = TextEditingController(text: ref.read(authProvider).email ?? '');
    final codeController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Lier un email (OTP)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'exemple@email.com',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Code OTP',
                hintText: '123456',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) return;
              try {
                await ref.read(authProvider.notifier).requestEmailOtp(email);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Code OTP envoyé par email.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Échec envoi OTP: $e')),
                );
              }
            },
            child: const Text('Envoyer OTP'),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              final code = codeController.text.trim();
              if (email.isEmpty || code.isEmpty) return;
              try {
                await ref
                    .read(authProvider.notifier)
                    .verifyEmailOtp(email: email, code: code);
                if (!mounted) return;
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Email vérifié avec succès.')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Vérification OTP échouée: $e')),
                );
              }
            },
            child: const Text(
              'Vérifier OTP',
              style: TextStyle(color: AppColors.primaryStart),
            ),
          ),
        ],
      ),
    );

    emailController.dispose();
    codeController.dispose();
  }
}

// ──────────────────────────────────────────────
// Private sub-widgets
// ──────────────────────────────────────────────

/// Gradient purple stat card with icon + badge, label and value.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.badgeIcon,
  });

  final IconData icon;
  final String label;
  final String value;
  final IconData? badgeIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFBF84F5),
            Color(0xFFA96CE4),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: Colors.white, size: 40),
              if (badgeIcon != null)
                Positioned(
                  bottom: -2,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFFA96CE4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(badgeIcon, color: Colors.white, size: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Row tile for the extra features section (on purple background).
class _ExtraTile extends StatelessWidget {
  const _ExtraTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withAlpha(40)),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withAlpha(180),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
