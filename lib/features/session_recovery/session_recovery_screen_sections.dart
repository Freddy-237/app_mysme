part of 'session_recovery_screen.dart';

extension _SessionRecoverySections on _SessionRecoveryScreenState {
  Widget _buildBody() {
    final auth = ref.watch(authProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            const Icon(
              Icons.lock_reset_rounded,
              size: 52,
              color: Color(0xFF6A1BDB),
            ),
            const SizedBox(height: 24),
            const Text(
              'Session perdue',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              auth.error ??
                  'Nous n\'avons pas pu restaurer ton identité précédente automatiquement.',
              style: const TextStyle(
                fontSize: 16,
                height: 1.5,
                color: Color(0xFF5F6173),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Tu peux récupérer ton compte avec une clé de récupération ou un email vérifié.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF7A7D90),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _recoverWithRecoveryKey,
                child: const Text('Restaurer avec une clé'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _recoverWithEmail,
                child: const Text('Restaurer par email'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _continueWithNewIdentity,
                child: const Text('Créer une nouvelle identité'),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
