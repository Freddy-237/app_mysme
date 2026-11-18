part of 'session_recovery_screen.dart';

extension _SessionRecoveryDialogs on _SessionRecoveryScreenState {
  Future<void> _continueWithNewIdentity() async {
    try {
      await ref.read(authProvider.notifier).createAnonymousIdentity();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      Helpers.showErrorSnack(
        context,
        e,
        fallback: 'Impossible de créer une nouvelle identité pour le moment.',
      );
    }
  }

  Future<void> _recoverWithRecoveryKey() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clé de récupération'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Entre ta clé',
            hintText: 'XXXX-XXXX-XXXX',
          ),
          textInputAction: TextInputAction.done,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isEmpty) return;
              try {
                await ref
                    .read(authProvider.notifier)
                    .restoreWithRecoveryKey(key);
                if (!dialogContext.mounted || !mounted) return;
                Navigator.pop(dialogContext);
                context.go('/home');
              } catch (e) {
                if (!dialogContext.mounted) return;
                Helpers.showErrorSnack(
                  dialogContext,
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

  Future<void> _recoverWithEmail() async {
    final emailController = TextEditingController();
    final codeController = TextEditingController();
    var otpSent = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Restaurer par email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (otpSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(labelText: 'Code OTP'),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            if (!otpSent)
              FilledButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  if (email.isEmpty) return;
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .requestEmailRestore(email);
                    if (!dialogContext.mounted) return;
                    setDialogState(() => otpSent = true);
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Si un compte est lié à cet email, un code vient d\'y être envoyé.')),
                    );
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    Helpers.showErrorSnack(
                      dialogContext,
                      e,
                      fallback: 'Impossible d\'envoyer le code pour le moment.',
                    );
                  }
                },
                child: const Text('Envoyer OTP'),
              ),
            if (otpSent)
              FilledButton(
                onPressed: () async {
                  final email = emailController.text.trim();
                  final code = codeController.text.trim();
                  if (email.isEmpty || code.isEmpty) return;
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .verifyEmailRestore(email, code);
                    if (!dialogContext.mounted || !mounted) return;
                    Navigator.pop(dialogContext);
                    context.go('/home');
                  } catch (e) {
                    if (!dialogContext.mounted) return;
                    Helpers.showErrorSnack(
                      dialogContext,
                      e,
                      fallback:
                          'Impossible de restaurer le compte avec ce code.',
                    );
                  }
                },
                child: const Text('Vérifier OTP'),
              ),
          ],
        ),
      ),
    );

    emailController.dispose();
    codeController.dispose();
  }
}
