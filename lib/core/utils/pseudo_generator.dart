import 'dart:math';

/// Generates unique anonymous pseudonyms like "SilentFox_42".
///
/// Used locally for instant identity creation.
/// Later, uniqueness will be validated server-side against the database.
class PseudoGenerator {
  PseudoGenerator._();

  static final _random = Random();

  static const List<String> adjectives = [
    'Silent',
    'Mystic',
    'Hidden',
    'Shadow',
    'Unknown',
    'Dark',
    'Calm',
    'Cosmic',
    'Secret',
    'Swift',
    'Bright',
    'Fading',
    'Frozen',
    'Gentle',
    'Stormy',
    'Lunar',
    'Solar',
    'Vivid',
    'Neon',
    'Golden',
    'Silver',
    'Crystal',
  ];

  static const List<String> nouns = [
    'Fox',
    'Wave',
    'Ghost',
    'Moon',
    'Echo',
    'Wolf',
    'Raven',
    'Spark',
    'Flame',
    'Frost',
    'Drift',
    'Storm',
    'Owl',
    'Hawk',
    'Lynx',
    'Tiger',
    'Viper',
    'Phoenix',
    'Comet',
    'Nova',
  ];

  /// Generate a pseudo like "SilentFox_42".
  static String generate() {
    final adj = adjectives[_random.nextInt(adjectives.length)];
    final noun = nouns[_random.nextInt(nouns.length)];
    final number = _random.nextInt(99) + 1;
    return '$adj${noun}_$number';
  }
}
