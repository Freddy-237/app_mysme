import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/chat/widgets/menu_button.dart';
import 'package:flutter/material.dart';

void main() {
  group('MenuButton', () {
    testWidgets('renders label text', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuButton(
              label: 'Test Label',
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.text('Test Label'), findsOneWidget);
    });

    testWidgets('renders icon when provided', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuButton(
              label: 'With Icon',
              icon: Icons.delete_outline,
              onTap: () {},
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('calls onTap callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MenuButton(
              label: 'Tap Me',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Tap Me'));
      expect(tapped, isTrue);
    });
  });
}
