import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/auth_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/features/identity/identity_screen.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthState initialState) : super(_FakeHttpClient()) {
    state = initialState;
  }

  bool createAnonymousIdentityCalled = false;
  bool failCreateAnonymousIdentity = false;

  @override
  Future<void> createAnonymousIdentity() async {
    createAnonymousIdentityCalled = true;
    if (failCreateAnonymousIdentity) {
      state = const AuthState(
        error: 'Impossible de preparer ton identite pour le moment.',
      );
      return;
    }

    state = const AuthState(
      userId: 'user-1',
      pseudo: 'Nova',
      avatarSeed: 'Nova',
    );
  }
}

Widget _buildIdentityApp(_FakeAuthNotifier notifier) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const IdentityScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('Home Route')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => notifier),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('IdentityScreen', () {
    testWidgets('shows preparation state while auth is loading',
        (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState(isLoading: true));

      await tester.pumpWidget(_buildIdentityApp(notifier));

      expect(find.text('Preparation de ton identite...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows retry state when identity is unavailable',
        (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState(
        error: 'Impossible de preparer ton identite pour le moment.',
      ));
      notifier.failCreateAnonymousIdentity = true;

      await tester.pumpWidget(_buildIdentityApp(notifier));
      await tester.pump();
      await tester.pump();

      expect(
        find.text('Impossible de preparer ton identite pour le moment.'),
        findsOneWidget,
      );
      expect(find.text('Reessayer'), findsOneWidget);
    });

    testWidgets('recovers missing identity automatically', (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState());

      await tester.pumpWidget(_buildIdentityApp(notifier));
      await tester.pump();
      await tester.pump();

      expect(notifier.createAnonymousIdentityCalled, isTrue);
      expect(find.text('Ton identité est prête'), findsOneWidget);
      expect(find.text('Nova'), findsOneWidget);
    });
  });
}
