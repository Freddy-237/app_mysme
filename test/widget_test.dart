import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/app/mystme_app.dart';

void main() {
  testWidgets('Splash screen renders app name', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MystmeApp(),
      ),
    );
    expect(find.text('MystMe'), findsOneWidget);
  });
}
