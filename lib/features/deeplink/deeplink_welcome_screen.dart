import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkWelcomeScreen extends StatefulWidget {
  const DeepLinkWelcomeScreen({
    super.key,
    required this.conversationId,
    this.pseudo,
    this.targetName,
  });

  final String conversationId;
  final String? pseudo;
  final String? targetName;

  @override
  State<DeepLinkWelcomeScreen> createState() => _DeepLinkWelcomeScreenState();
}

class _DeepLinkWelcomeScreenState extends State<DeepLinkWelcomeScreen> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      context.go('/chat/${widget.conversationId}');
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayPseudo = (widget.pseudo == null || widget.pseudo!.isEmpty)
        ? 'Ghost_92'
        : widget.pseudo!;
    final target = (widget.targetName == null || widget.targetName!.isEmpty)
        ? 'cette personne'
        : '@${widget.targetName}';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      body: Center(
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
      ),
    );
  }
}
