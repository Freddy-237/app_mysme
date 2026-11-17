import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/chat/widgets/chat_header.dart';

void main() {
  Widget buildHeader({
    String? trustLevel,
    bool identityRevealed = false,
    bool isTyping = false,
    bool isOnline = true,
    VoidCallback? onBack,
    VoidCallback? onTrustTap,
    VoidCallback? onMenu,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatHeader(
          topPadding: 0,
          peerPseudo: 'Myst',
          identityRevealed: identityRevealed,
          trustLevel: trustLevel,
          isTyping: isTyping,
          isOnline: isOnline,
          formattedRemaining: '-3j',
          onBack: onBack ?? () {},
          onTrustTap: onTrustTap ?? () {},
          onMenu: onMenu ?? () {},
        ),
      ),
    );
  }

  group('ChatHeader trust badge', () {
    testWidgets('shows anonymous trust by default', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.text('Anonyme'), findsOneWidget);
      expect(find.text('Myst'), findsOneWidget);
    });

    testWidgets('shows trusted label when trust level is trusted',
        (tester) async {
      await tester.pumpWidget(buildHeader(trustLevel: 'trusted'));

      expect(find.text('Fiable'), findsOneWidget);
    });

    testWidgets('shows revealed title when identity is revealed',
        (tester) async {
      await tester.pumpWidget(
        buildHeader(trustLevel: 'revealed', identityRevealed: true),
      );

      expect(find.text('Identité révélée'), findsOneWidget);
      expect(find.text('Révélé'), findsOneWidget);
    });

    testWidgets('calls trust tap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildHeader(onTrustTap: () => tapped = true),
      );

      await tester.tap(find.text('Anonyme'));
      expect(tapped, isTrue);
    });

    testWidgets('shows typing label with priority over online state',
        (tester) async {
      await tester.pumpWidget(
        buildHeader(isTyping: true, isOnline: true),
      );

      expect(find.text("en train d'écrire..."), findsOneWidget);
      expect(find.text('En ligne'), findsNothing);
    });

    testWidgets('shows offline label when peer is disconnected',
        (tester) async {
      await tester.pumpWidget(
        buildHeader(isOnline: false),
      );

      expect(find.text('Hors ligne'), findsOneWidget);
    });

    testWidgets('calls back and menu callbacks', (tester) async {
      var backTapped = false;
      var menuTapped = false;

      await tester.pumpWidget(
        buildHeader(
          onBack: () => backTapped = true,
          onMenu: () => menuTapped = true,
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.more_vert));

      expect(backTapped, isTrue);
      expect(menuTapped, isTrue);
    });
  });
}
