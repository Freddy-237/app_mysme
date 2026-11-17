import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/discussions/widgets/tab_selector.dart';

void main() {
  Widget buildSelector({
    required int selectedIndex,
    required ValueChanged<int> onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: TabSelector(
          selectedIndex: selectedIndex,
          onTap: onTap,
        ),
      ),
    );
  }

  group('TabSelector', () {
    testWidgets('renders both discussion tabs', (tester) async {
      await tester.pumpWidget(
        buildSelector(selectedIndex: 0, onTap: (_) {}),
      );

      expect(find.text('Propriétaire'), findsOneWidget);
      expect(find.text('Anonyme'), findsOneWidget);
    });

    testWidgets('forwards selected tab index on tap', (tester) async {
      var tappedIndex = -1;

      await tester.pumpWidget(
        buildSelector(selectedIndex: 0, onTap: (index) => tappedIndex = index),
      );

      await tester.tap(find.text('Anonyme'));
      expect(tappedIndex, 1);

      await tester.tap(find.text('Propriétaire'));
      expect(tappedIndex, 0);
    });
  });
}
