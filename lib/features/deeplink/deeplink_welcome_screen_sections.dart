part of 'deeplink_welcome_screen.dart';

extension _DeepLinkWelcomeSections on _DeepLinkWelcomeScreenState {
  String _displayPseudo() {
    final pseudo = widget.pseudo;
    return (pseudo == null || pseudo.isEmpty) ? 'Ghost_92' : pseudo;
  }

  String _targetName() {
    final targetName = widget.targetName;
    return (targetName == null || targetName.isEmpty)
        ? 'cette personne'
        : '@$targetName';
  }

  Widget _buildBody() {
    final displayPseudo = _displayPseudo();
    final target = _targetName();

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '👋 Bon retour $displayPseudo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4A2D72),
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Ta conversation avec $target est prête.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B5F78),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 22),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          ],
        ),
      ),
    );
  }
}
