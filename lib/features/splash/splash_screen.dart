import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/providers.dart';

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
      final existingToken = await storage.read(key: 'mystme_token');

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
      // Returning user who already completed onboarding → go home.
      if (onboardingDone == 'true' &&
          (auth.isAuthenticated || existingToken != null)) {
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
      _goSafely(done == 'true' ? '/home' : '/onboarding');
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
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo placeholder (purple circle + mask icon)
              Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF5A2EBE), Color(0xFF9B6DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(
                  Icons.masks_outlined,
                  color: Colors.white,
                  size: 56,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'MystMe',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A2EBE),
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF9B6DFF)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
