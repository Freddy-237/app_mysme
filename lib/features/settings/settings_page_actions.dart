part of 'settings_page.dart';

const _supportEmail = 'contact@fridevs.com';

extension _SettingsPageActions on _SettingsPageState {
  Future<void> _openSupport() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Contacter le support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pour toute aide, bug ou question liée à ton compte, contacte-nous à :',
            ),
            SizedBox(height: 12),
            SelectableText(
              _supportEmail,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.primaryStart,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
          FilledButton(
            onPressed: () async {
              await Clipboard.setData(
                const ClipboardData(text: _supportEmail),
              );
              if (!dialogContext.mounted || !mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Adresse email copiée'),
                ),
              );
            },
            child: const Text('Copier'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer mon compte ?'),
        content: const Text(
          'Ton compte, ton lien, toutes tes conversations et tous tes '
          'messages seront effacés définitivement, pour toi comme pour tes '
          'correspondants.\n\nCette action est irréversible : ni ta clé de '
          'récupération ni ton email ne permettront de revenir en arrière.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    _setDeletingAccount(true);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (e) {
      if (!mounted) return;
      _setDeletingAccount(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            Helpers.friendlyErrorMessage(
              e,
              fallback:
                  'Suppression impossible pour le moment. Ton compte est intact, réessaie.',
            ),
          ),
        ),
      );
      return;
    }

    // The account is gone on the server: forget everything it left here.
    await _wipeLocalAccountData();
    if (!mounted) return;
    context.go('/onboarding');
  }

  /// Best effort: a failure here must not block leaving the deleted account.
  Future<void> _wipeLocalAccountData() async {
    try {
      ref.read(socketServiceProvider).disconnect();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in prefs.getKeys().toList()) {
        // Keep device preferences (theme); drop everything tied to the account.
        if (key.startsWith('mystme_') && key != 'mystme_theme_mode') {
          await prefs.remove(key);
        }
      }
    } catch (_) {}
    try {
      await ref
          .read(secureStorageProvider)
          .delete(key: 'mystme_onboarding_complete');
    } catch (_) {}
    ref.invalidate(conversationProvider);
    ref.invalidate(linkProvider);
    ref.invalidate(offlineQueueProvider);
  }

  Future<void> _openTerms() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conditions d\'utilisation',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'MystMe est un espace de discussion anonyme. Tu t\'engages à utiliser l\'application de manière légale, respectueuse et sans harcèlement.',
                  style: TextStyle(height: 1.5, color: AppColors.textSecondary),
                ),
                SizedBox(height: 12),
                Text(
                  'Les contenus abusifs, menaçants, haineux, frauduleux ou sexuellement explicites peuvent entraîner une suspension du compte et la suppression des conversations concernées.',
                  style: TextStyle(height: 1.5, color: AppColors.textSecondary),
                ),
                SizedBox(height: 12),
                Text(
                  'Tu restes responsable des informations que tu partages. Évite de publier des données personnelles sensibles, les tiennes comme celles des autres.',
                  style: TextStyle(height: 1.5, color: AppColors.textSecondary),
                ),
                SizedBox(height: 12),
                Text(
                  'Si tu as une question juridique ou un signalement, contacte le support depuis cette page.',
                  style: TextStyle(height: 1.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
