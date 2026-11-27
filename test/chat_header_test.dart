import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/chat/widgets/chat_header.dart';

void main() {
  Widget buildHeader({
    bool isTyping = false,
    bool isOnline = true,
    VoidCallback? onBack,
    VoidCallback? onMenu,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ChatHeader(
          topPadding: 0,
          peerPseudo: 'Myst',
          isTyping: isTyping,
          isOnline: isOnline,
          formattedRemaining: '-3j',
          onBack: onBack ?? () {},
          onMenu: onMenu ?? () {},
        ),
      ),
    );
  }

  group('ChatHeader', () {
    testWidgets('shows the peer name and no trust badge', (tester) async {
      await tester.pumpWidget(buildHeader());

      expect(find.text('Myst'), findsOneWidget);
      // The unfinished trust levels were removed before launch.
      for (final label in ['Anonyme', 'Nouveau', 'Fiable', 'Révélé']) {
        expect(find.text(label), findsNothing);
      }
      expect(find.text('Identité révélée'), findsNothing);
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
