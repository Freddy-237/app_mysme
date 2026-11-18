import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'deeplink_welcome_screen_sections.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF7F3FF),
      body: _buildBody(),
    );
  }
}
