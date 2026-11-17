import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/features/deeplink/deeplink_welcome_screen.dart';

Widget _buildTestApp({
  String? pseudo,
  String? targetName,
  String conversationId = 'conv-123',
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => DeepLinkWelcomeScreen(
          conversationId: conversationId,
          pseudo: pseudo,
          targetName: targetName,
        ),
      ),
      GoRoute(
        path: '/chat/:conversationId',
        builder: (context, state) => Scaffold(
          body: Text('Chat ${state.pathParameters['conversationId']}'),
        ),
      ),
    ],
  );

  return MaterialApp.router(routerConfig: router);
}

void main() {
  group('DeepLinkWelcomeScreen', () {
    testWidgets('shows provided pseudo and target name', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(pseudo: 'Nova', targetName: 'Mika'),
      );

      expect(find.text('👋 Bon retour Nova'), findsOneWidget);
      expect(
          find.text('Ta conversation avec @Mika est prête.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('falls back to default pseudo and target name', (tester) async {
      await tester.pumpWidget(_buildTestApp());

      expect(find.text('👋 Bon retour Ghost_92'), findsOneWidget);
      expect(
        find.text('Ta conversation avec cette personne est prête.'),
        findsOneWidget,
      );
    });

    testWidgets('redirects automatically to the chat route', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(conversationId: 'conv-999', pseudo: 'Nova'),
      );

      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      expect(find.text('Chat conv-999'), findsOneWidget);
    });
  });
}
