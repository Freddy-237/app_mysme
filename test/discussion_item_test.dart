import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/discussions/widgets/discussion_item.dart';
import 'package:mysme/shared/widgets/seed_avatar.dart';

void main() {
  Widget buildItem({
    bool unread = false,
    int unreadCount = 0,
    String avatarSeed = '',
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: DiscussionItem(
          title: 'Alice',
          message: 'Salut toi',
          time: '09:41',
          unread: unread,
          unreadCount: unreadCount,
          avatarSeed: avatarSeed,
          onTap: onTap,
        ),
      ),
    );
  }

  group('DiscussionItem', () {
    testWidgets('renders fallback avatar and base content', (tester) async {
      await tester.pumpWidget(buildItem());

      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Salut toi'), findsOneWidget);
      expect(find.text('09:41'), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsOneWidget);
      expect(find.byType(SeedAvatar), findsNothing);
    });

    testWidgets('renders seed avatar when avatar seed is provided',
        (tester) async {
      await tester.pumpWidget(buildItem(avatarSeed: 'peer-42'));

      expect(find.byType(SeedAvatar), findsOneWidget);
      expect(find.byIcon(Icons.person_rounded), findsNothing);
    });

    testWidgets('shows unread counter badge when more than one unread message',
        (tester) async {
      await tester.pumpWidget(buildItem(unread: true, unreadCount: 3));

      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('shows unread dot when exactly one unread message',
        (tester) async {
      await tester.pumpWidget(buildItem(unread: true, unreadCount: 1));

      final unreadDot = find.byWidgetPredicate((widget) {
        if (widget is! Container) return false;
        final decoration = widget.decoration;
        final constraints = widget.constraints;
        return decoration is BoxDecoration &&
            decoration.shape == BoxShape.circle &&
            constraints?.minWidth == 10 &&
            constraints?.maxWidth == 10 &&
            constraints?.minHeight == 10 &&
            constraints?.maxHeight == 10;
      });

      expect(unreadDot, findsOneWidget);
      expect(find.text('1'), findsNothing);
    });

    testWidgets('calls tap callback', (tester) async {
      var tapped = false;

      await tester.pumpWidget(buildItem(onTap: () => tapped = true));
      await tester.tap(find.byType(InkWell));

      expect(tapped, isTrue);
    });
  });
}
