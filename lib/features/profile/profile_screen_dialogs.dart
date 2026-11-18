part of 'profile_screen.dart';

extension _ProfileScreenDialogs on _ProfileScreenState {
  void _showRegenerateDialog() {
    showDialog<void>(
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
              try {
                await ref.read(authProvider.notifier).regenerateIdentity();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nouvelle identité générée.'),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                Helpers.showErrorSnack(
                  context,
                  e,
                  fallback:
                      'Impossible de régénérer ton identité pour le moment.',
                );
              }
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

      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible de générer la clé de récupération.',
      );
    }
  }

  Future<void> _showRestoreChoiceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Restaurer mon compte'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Comment souhaitez-vous restaurer votre compte ?'),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showRestoreRecoveryKeyDialog();
              },
              icon: const Icon(Icons.key_rounded),
              label: const Text('Clé de récupération'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryStart,
                side: const BorderSide(color: AppColors.primaryStart),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _showEmailRestoreDialog();
              },
              icon: const Icon(Icons.email_rounded),
              label: const Text('Par email'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryStart,
                side: const BorderSide(color: AppColors.primaryStart),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEmailRestoreDialog() async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    var isBusy = false;
    var otpSent = false;

    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Restaurer par email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email vérifié',
                  hintText: 'exemple@email.com',
                ),
              ),
              if (otpSent) ...[
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
            ],
          ),
          actions: [
            TextButton(
              onPressed: isBusy ? null : () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            if (!otpSent)
              TextButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        if (email.isEmpty) return;
                        setDialogState(() => isBusy = true);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .requestEmailRestore(email);
                          setDialogState(() {
                            isBusy = false;
                            otpSent = true;
                          });
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Code OTP envoyé par email.')),
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setDialogState(() => isBusy = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                Helpers.friendlyErrorMessage(
                                  e,
                                  fallback:
                                      'Impossible d\'envoyer le code pour le moment.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Envoyer OTP'),
              ),
            if (otpSent)
              TextButton(
                onPressed: isBusy
                    ? null
                    : () async {
                        final email = emailController.text.trim();
                        final code = codeController.text.trim();
                        if (email.isEmpty || code.isEmpty) return;
                        setDialogState(() => isBusy = true);
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .verifyEmailRestore(email, code);
                          if (ctx.mounted) {
                            Navigator.of(ctx, rootNavigator: true).pop();
                          }
                          if (mounted) {
                            await ref.read(authProvider.notifier).refreshMe();
                          }
                          messenger.showSnackBar(
                            const SnackBar(
                                content: Text('Compte restauré avec succès.')),
                          );
                        } catch (e) {
                          if (!ctx.mounted) return;
                          setDialogState(() => isBusy = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                Helpers.friendlyErrorMessage(
                                  e,
                                  fallback:
                                      'Impossible de restaurer le compte avec ce code.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                child: isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Restaurer',
                        style: TextStyle(color: AppColors.primaryStart),
                      ),
              ),
          ],
        ),
      ),
    );

    emailController.dispose();
    codeController.dispose();
  }

  Future<void> _showRestoreRecoveryKeyDialog() async {
    final controller = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              final messenger = ScaffoldMessenger.of(ctx);
              Navigator.pop(ctx);
              try {
                await ref
                    .read(authProvider.notifier)
                    .restoreWithRecoveryKey(key);
                if (mounted) await ref.read(authProvider.notifier).refreshMe();
                messenger.showSnackBar(
                  const SnackBar(content: Text('Compte restauré avec succès.')),
                );
              } catch (e) {
                if (!mounted) return;
                Helpers.showErrorSnack(
                  context,
                  e,
                  fallback: 'Impossible de restaurer le compte avec cette clé.',
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
    final emailController =
        TextEditingController(text: ref.read(authProvider).email ?? '');
    final codeController = TextEditingController();
    var isBusy = false;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
              onPressed: isBusy ? null : () => Navigator.pop(ctx),
              child: const Text('Fermer'),
            ),
            TextButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      if (email.isEmpty) return;
                      setDialogState(() => isBusy = true);
                      try {
                        await ref
                            .read(authProvider.notifier)
                            .requestEmailOtp(email);
                        if (!ctx.mounted) return;
                        setDialogState(() => isBusy = false);
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Code OTP envoyé par email.')),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isBusy = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              Helpers.friendlyErrorMessage(
                                e,
                                fallback:
                                    'Impossible d\'envoyer le code pour le moment.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
              child: const Text('Envoyer OTP'),
            ),
            TextButton(
              onPressed: isBusy
                  ? null
                  : () async {
                      final email = emailController.text.trim();
                      final code = codeController.text.trim();
                      if (email.isEmpty || code.isEmpty) return;
                      setDialogState(() => isBusy = true);
                      try {
                        await ref.read(authProvider.notifier).verifyEmailOtp(
                              email: email,
                              code: code,
                            );
                        if (ctx.mounted) {
                          Navigator.of(ctx, rootNavigator: true).pop();
                        }
                        if (mounted) {
                          await ref.read(authProvider.notifier).refreshMe();
                        }
                        messenger.showSnackBar(
                          const SnackBar(
                              content: Text('Email vérifié avec succès.')),
                        );
                      } catch (e) {
                        if (!ctx.mounted) return;
                        setDialogState(() => isBusy = false);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              Helpers.friendlyErrorMessage(
                                e,
                                fallback:
                                    'Impossible de vérifier ce code pour le moment.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
              child: isBusy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Vérifier OTP',
                      style: TextStyle(color: AppColors.primaryStart),
                    ),
            ),
          ],
        ),
      ),
    );

    emailController.dispose();
    codeController.dispose();
  }
}
