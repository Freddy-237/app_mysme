import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

/// Page 3 — Génération de l'identité anonyme.
///
/// Displays the identity already created by the backend (via authProvider.init).
/// The user sees the pseudo + avatar with a scale animation, then taps Continue.
class IdentityScreen extends ConsumerStatefulWidget {
  const IdentityScreen({super.key});

  @override
  ConsumerState<IdentityScreen> createState() => _IdentityScreenState();
}

class _IdentityScreenState extends ConsumerState<IdentityScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scale = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() async {
    // Mark onboarding as completed so we skip it on next launch.
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: 'mystme_onboarding_complete', value: 'true');
    if (!mounted) return;
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final pseudo = auth.pseudo ?? 'Inconnu';
    final avatarSeed = auth.avatarSeed ?? pseudo;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar animé (scale)
            ScaleTransition(
              scale: _scale,
              child: SeedAvatar(seed: avatarSeed, size: 120),
            ),

            const SizedBox(height: 24),

            // Titre
            const Text(
              'Ton identité est prête',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),

            const SizedBox(height: 8),

            // Pseudo généré
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
          ],
        ),
      ),
    );
  }
}
