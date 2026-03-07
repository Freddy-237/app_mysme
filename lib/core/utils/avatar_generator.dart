import 'dart:math';

/// Generates a deterministic seed for avatar rendering.
///
/// The seed is a 12-digit numeric string used to produce
/// a unique visual identity (geometric shapes, colors, etc.).
/// Later this seed will drive DiceBear / SVG / remote avatar APIs.
class AvatarGenerator {
  AvatarGenerator._();

  static final _random = Random();

  /// Generate a 12-character numeric seed.
  static String generateSeed() {
    return List.generate(12, (_) => _random.nextInt(9)).join();
  }
}
