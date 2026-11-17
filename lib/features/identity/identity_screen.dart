import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/features/transfer/transfer_dialog.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

part 'identity_screen_sections.dart';

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
  bool _requestedIdentitySetup = false;

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

  Future<void> _ensureIdentityReady() async {
    if (_requestedIdentitySetup) return;

    setState(() => _requestedIdentitySetup = true);
    try {
      await ref.read(authProvider.notifier).createAnonymousIdentity();
    } finally {
      if (mounted) {
        setState(() => _requestedIdentitySetup = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isAuthenticated && !auth.isLoading && !_requestedIdentitySetup) {
      Future.microtask(_ensureIdentityReady);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(),
    );
  }
}
