import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';

part 'splash_screen_sections.dart';

/// Splash screen — bootstraps auth, then routes to home or onboarding.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  void _goSafely(String route) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(route);
    });
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );
    _fadeController.forward();

    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final storage = ref.read(secureStorageProvider);
      final onboardingDone =
          await storage.read(key: 'mystme_onboarding_complete');

      // Init auth (loads or creates identity via backend).
      // Short timeout so the splash never hangs when backend is down.
      await ref
          .read(authProvider.notifier)
          .init()
          .timeout(const Duration(seconds: 6));

      // Small delay so logo is visible.
      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      final auth = ref.read(authProvider);
      if (auth.sessionLost) {
        _goSafely('/session-recovery');
        return;
      }

      // Returning user who already completed onboarding. A stored session
      // counts even if the server could not be reached (offline start):
      // sending them to onboarding would create a NEW identity.
      final hasAccount =
          auth.isAuthenticated || ref.read(httpClientProvider).hasStoredSession;
      if (onboardingDone == 'true' && hasAccount) {
        _goSafely('/home');
      } else {
        _goSafely('/onboarding');
      }
    } catch (e) {
      debugPrint('Bootstrap error: $e');
      if (!mounted) return;
      // If onboarding was already completed, go home even on error.
      final storage = ref.read(secureStorageProvider);
      final done = await storage.read(key: 'mystme_onboarding_complete');
      final auth = ref.read(authProvider);
      final hasAccount =
          auth.isAuthenticated || ref.read(httpClientProvider).hasStoredSession;
      _goSafely(done == 'true' && hasAccount ? '/home' : '/onboarding');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
    );
  }
}
