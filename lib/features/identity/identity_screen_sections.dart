part of 'identity_screen.dart';

extension _IdentityScreenSections on _IdentityScreenState {
  Widget _buildBody() {
    final auth = ref.watch(authProvider);
    final isPreparingIdentity = auth.isLoading || _requestedIdentitySetup;

    if (!auth.isAuthenticated) {
      if (isPreparingIdentity) {
        return const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Preparation de ton identite...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied_rounded,
                  size: 56,
                  color: Color(0xFF6A1BDB),
                ),
                const SizedBox(height: 18),
                Text(
                  auth.error ??
                      'Impossible de preparer ton identite pour le moment.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _ensureIdentityReady,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1BDB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('Reessayer'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pseudo = auth.pseudo ?? 'Inconnu';
    final avatarSeed = auth.avatarSeed ?? pseudo;

    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Avatar animé (scale)
          ScaleTransition(
            scale: _scale,
            // Pseudo généré
            child: SeedAvatar(seed: avatarSeed, size: 120),
          ),

          const SizedBox(height: 24),

          // Titre
          const Text(
            'Ton identité est prête',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Pseudo genere
          Text(
            pseudo,
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFF6A1BDB),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 32),

          // Bouton Continuer
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1BDB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'CONTINUER',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showWebTransferDialog(context, ref),
            child: const Text(
              'Tu as commencé sur le web ? Récupère ta conversation',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6A1BDB)),
            ),
          ),
        ],
      ),
    );
  }
}
