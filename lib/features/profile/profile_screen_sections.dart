// ignore_for_file: invalid_use_of_protected_member

part of 'profile_screen.dart';

extension _ProfileScreenSections on _ProfileScreenState {
  Widget _buildProfileCard(
    String avatarSeed,
    String userName,
    String currentBio,
  ) {
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
          Stack(
            clipBehavior: Clip.none,
            children: [
              SeedAvatar(seed: avatarSeed, size: 100),
              Positioned(
                bottom: 0,
                right: -4,
                child: GestureDetector(
                  onTap: _showRegenerateDialog,
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
                          color: AppColors.primaryStart,
                          width: 2,
                        ),
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
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () async {
                if (_isEditingBio) {
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .updateBio(_bioController.text);
                    if (!mounted) return;
                    setState(() => _isEditingBio = false);
                  } catch (error) {
                    if (!mounted) return;
                    Helpers.showErrorSnack(
                      context,
                      error,
                      fallback:
                          'Impossible d\'enregistrer la bio pour le moment.',
                    );
                  }
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
              label: 'Anonyme',
              value: anonymousCount,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.person_rounded,
              label: 'Proprietaire',
              value: ownerCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraSection(
      String linkUrl, String linkDisplay, String userName) {
    final auth = ref.watch(authProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _ExtraTile(
            icon: Icons.link_rounded,
            label: 'Copier mon lien',
            subtitle: linkDisplay.toUpperCase(),
            trailing:
                const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
            onTap: () async {
              try {
                var finalLinkUrl = linkUrl;
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
              } catch (error) {
                if (kDebugMode) {
                  debugPrint('[ProfileScreen] Copy link failed: $error');
                }
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
          _ExtraTile(
            icon: Icons.refresh_rounded,
            label: 'Régénérer mon identité',
            subtitle: 'Nouveau pseudo & avatar',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showRegenerateDialog,
          ),
          const SizedBox(height: 10),
          _ExtraTile(
            icon: Icons.key_outlined,
            label: 'Sauvegarder mon compte',
            subtitle: 'Générer une clé de récupération',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showGenerateRecoveryKeyDialog,
          ),
          const SizedBox(height: 10),
          _ExtraTile(
            icon: Icons.restore_rounded,
            label: 'Restaurer mon compte',
            subtitle: 'Clé de récupération ou email',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: _showRestoreChoiceDialog,
          ),
          const SizedBox(height: 10),
          _ExtraTile(
            icon: Icons.move_down_rounded,
            label: 'Récupérer une conversation web',
            subtitle: 'Code affiché sur la page MystMe',
            trailing: const Icon(Icons.chevron_right_rounded,
                color: Colors.white, size: 22),
            onTap: () => showWebTransferDialog(context, ref),
          ),
          const SizedBox(height: 10),
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
        ],
      ),
    );
  }
}
