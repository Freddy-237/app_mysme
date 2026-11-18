import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/auth_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/features/settings/settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier({this.fail = false})
      : super(HttpClient(const FlutterSecureStorage()));

  final bool fail;
  int deleteCalls = 0;

  @override
  Future<void> deleteAccount() async {
    deleteCalls += 1;
    if (fail) throw ApiException('Serveur indisponible', 503);
    state = const AuthState();
  }
}

Future<void> _pump(WidgetTester tester, _FakeAuthNotifier auth) async {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const Scaffold(body: Text('ONBOARDING')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith((ref) => auth)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openDialog(WidgetTester tester) async {
  final tile = find.text('Supprimer mon compte');
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({
      'mystme_onboarding_complete': 'true',
    });
    SharedPreferences.setMockInitialValues({
      'mystme_conversations_cache_v1': '{"items":[]}',
      'mystme_theme_mode': 'dark',
    });
  });

  testWidgets('cancelling the confirmation deletes nothing', (tester) async {
    final auth = _FakeAuthNotifier();
    await _pump(tester, auth);
    await _openDialog(tester);

    expect(find.text('Supprimer mon compte ?'), findsOneWidget);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 0);
    expect(find.text('ONBOARDING'), findsNothing);
  });

  testWidgets('confirming deletes the account, wipes local data, leaves',
      (tester) async {
    final auth = _FakeAuthNotifier();
    await _pump(tester, auth);
    await _openDialog(tester);

    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 1);
    expect(find.text('ONBOARDING'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mystme_conversations_cache_v1'), isNull);
    expect(prefs.getString('mystme_theme_mode'), 'dark');
    expect(
      await const FlutterSecureStorage()
          .read(key: 'mystme_onboarding_complete'),
      isNull,
    );
  });

  testWidgets('a server failure keeps the account and stays on the page',
      (tester) async {
    final auth = _FakeAuthNotifier(fail: true);
    await _pump(tester, auth);
    await _openDialog(tester);

    await tester.tap(find.text('Supprimer définitivement'));
    await tester.pumpAndSettle();

    expect(auth.deleteCalls, 1);
    expect(find.text('ONBOARDING'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('mystme_conversations_cache_v1'), isNotNull);
  });
}
