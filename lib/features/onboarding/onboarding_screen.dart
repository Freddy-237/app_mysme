import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

part 'onboarding_screen_sections.dart';
part 'onboarding_screen_widgets.dart';

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.emoji,
    required this.title,
    required this.description,
    required this.badge,
  });

  final String emoji;
  final String title;
  final String description;
  final String badge;
}

/// Three-page onboarding — fond violet clair, navigation blanche.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> pages = const [
    _OnboardingPageData(
      emoji: '💌',
      badge: 'Discret et direct',
      title: 'Parle sans pression',
      description: 'Lance une discussion simple, fun et un peu mysterieuse.',
    ),
    _OnboardingPageData(
      emoji: '🌟',
      badge: 'Ton espace',
      title: 'Cree ton vibe',
      description:
          'Ajoute ton style, ton profil et laisse la curiosite faire le reste.',
    ),
  ];

  void _next() {
    if (_currentPage < pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/identity');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
