part of 'onboarding_screen.dart';

class _OnboardingBadge extends StatelessWidget {
  const _OnboardingBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0DEFF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6A1BDB),
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _OnboardingEmojiCard extends StatelessWidget {
  const _OnboardingEmojiCard({required this.emoji});

  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 320, maxHeight: 320),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3E3FF)],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1C6A1BDB),
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 92),
          ),
          const SizedBox(height: 18),
          Container(
            width: 72,
            height: 8,
            decoration: BoxDecoration(
              color: const Color(0xFFE4C8FF),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dot indicator.
class _Dot extends StatelessWidget {
  const _Dot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: active ? 12 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? const Color(0xFF6A1BDB) : const Color(0xFFC7A9F5),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
