part of 'home_screen.dart';

extension _HomeScreenSections on _HomeScreenState {
  /// Violet gradient header with user pseudo & avatar.
  Widget _buildHeader() {
    final auth = ref.watch(authProvider);
    final pseudo = auth.pseudo ?? 'Anonyme';
    final seed = auth.avatarSeed ?? 'default';

    return Container(
      height: 196,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryStart, AppColors.primaryEnd],
        ),
        borderRadius: BorderRadius.only(
          bottomRight: Radius.circular(80),
        ),
      ),
      padding: const EdgeInsets.only(top: 54, left: 20, right: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salut,',
                  style: TextStyle(
                    color: Colors.white.withAlpha(180),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pseudo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: SeedAvatar(seed: seed, size: 50),
          ),
        ],
      ),
    );
  }

  /// Scrollable content: share card + link card.
  Widget _buildContent() {
    final warningMessage = ref.watch(authProvider).systemWarningMessage;

    return Padding(
      padding: const EdgeInsets.only(top: 152),
      child: SingleChildScrollView(
        child: Column(
          children: [
            if (warningMessage != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFFC067)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFB76A00),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        warningMessage,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xFF7A4A00),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const ShareCard(),
            const SizedBox(height: 16),
            const LinkCard(),
            const SizedBox(height: 14),
            const ShareWith(),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}
