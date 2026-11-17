import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mysme/core/providers/auth_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/providers/providers.dart';
import 'package:mysme/features/splash/splash_screen.dart';
import 'package:mysme/features/session_recovery/session_recovery_screen.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient({
    this.failInitWithSessionLost = false,
  }) : super(const FlutterSecureStorage());

  final bool failInitWithSessionLost;
  bool _ready = false;
  bool createAnonymousIdentityCalled = false;

  @override
  bool get isReady => _ready;

  @override
  Future<void> init() async {
    if (failInitWithSessionLost) {
      throw SessionLostException('Session expirée');
    }
    _ready = true;
  }

  @override
  Future<void> createAnonymousIdentity() async {
    createAnonymousIdentityCalled = true;
    _ready = true;
  }

  @override
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    if (path == '/identity/me') {
      return {
        'id': 'user-1',
        'pseudo': 'Fox',
        'avatar_url': null,
        'bio': '',
        'email': null,
        'email_verified_at': null,
        'notifications_enabled': false,
      };
    }
    throw UnimplementedError('Unhandled GET path: $path');
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(AuthState initialState)
      : super(_FakeHttpClient(failInitWithSessionLost: true)) {
    state = initialState;
  }

  AuthState? nextInitState;
  bool createAnonymousIdentityCalled = false;

  @override
  Future<void> init() async {
    if (nextInitState != null) {
      state = nextInitState!;
    }
  }

  @override
  Future<void> createAnonymousIdentity() async {
    createAnonymousIdentityCalled = true;
    state = const AuthState(
      userId: 'new-user',
      pseudo: 'Nova',
    );
  }

  @override
  Future<void> restoreWithRecoveryKey(String recoveryKey) async {}

  @override
  Future<Map<String, dynamic>> requestEmailRestore(String email) async => {};

  @override
  Future<void> verifyEmailRestore(String email, String code) async {}
}

class _FakeSecureStorage extends FlutterSecureStorage {
  _FakeSecureStorage(this._values);

  final Map<String, String> _values;

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    return _values[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    if (value == null) {
      _values.remove(key);
      return;
    }
    _values[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    AppleOptions? mOptions,
  }) async {
    _values.remove(key);
  }
}

Widget _buildSplashTestApp({
  required _FakeAuthNotifier notifier,
  required FlutterSecureStorage storage,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/session-recovery',
        builder: (context, state) => const Scaffold(
          body: Text('Session Recovery Route'),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Text('Home Route'),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const Scaffold(
          body: Text('Onboarding Route'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => notifier),
      secureStorageProvider.overrideWithValue(storage),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

Widget _buildSessionRecoveryTestApp({
  required _FakeAuthNotifier notifier,
}) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const SessionRecoveryScreen(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(
          body: Text('Home Route'),
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authProvider.overrideWith((ref) => notifier),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  group('AuthNotifier session recovery', () {
    test('init exposes sessionLost instead of creating a new identity',
        () async {
      final notifier =
          AuthNotifier(_FakeHttpClient(failInitWithSessionLost: true));

      await notifier.init();

      expect(notifier.state.sessionLost, isTrue);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.error, contains('Session expirée'));
    });

    test('createAnonymousIdentity hydrates the restored auth state', () async {
      final client = _FakeHttpClient();
      final notifier = AuthNotifier(client);

      await notifier.createAnonymousIdentity();

      expect(client.createAnonymousIdentityCalled, isTrue);
      expect(notifier.state.sessionLost, isFalse);
      expect(notifier.state.userId, 'user-1');
      expect(notifier.state.pseudo, 'Fox');
    });
  });

  group('SessionRecoveryScreen', () {
    testWidgets('renders recovery actions and shows recovery key dialog',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState(
          sessionLost: true,
          error: 'Session expirée',
        ),
      );

      await tester.pumpWidget(
        _buildSessionRecoveryTestApp(notifier: notifier),
      );

      expect(find.text('Session perdue'), findsOneWidget);
      expect(find.text('Restaurer avec une clé'), findsOneWidget);
      expect(find.text('Restaurer par email'), findsOneWidget);
      expect(find.text('Créer une nouvelle identité'), findsOneWidget);

      await tester.tap(find.text('Restaurer avec une clé'));
      await tester.pumpAndSettle();

      expect(find.text('Clé de récupération'), findsOneWidget);
      expect(find.text('Restaurer'), findsOneWidget);
    });

    testWidgets('shows email recovery dialog', (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState(sessionLost: true));

      await tester.pumpWidget(
        _buildSessionRecoveryTestApp(notifier: notifier),
      );

      await tester.tap(find.text('Restaurer par email'));
      await tester.pumpAndSettle();

      expect(find.text('Restaurer par email'), findsNWidgets(2));
      expect(find.text('Envoyer OTP'), findsOneWidget);
      expect(find.text('Email'), findsOneWidget);
    });

    testWidgets('can continue with a new identity', (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState(sessionLost: true));

      await tester.pumpWidget(
        _buildSessionRecoveryTestApp(notifier: notifier),
      );

      await tester.tap(find.text('Créer une nouvelle identité'));
      await tester.pumpAndSettle();

      expect(notifier.createAnonymousIdentityCalled, isTrue);
      expect(find.text('Home Route'), findsOneWidget);
    });
  });

  group('SplashScreen routing', () {
    testWidgets('redirects to session recovery when session is lost',
        (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState())
        ..nextInitState = const AuthState(
          sessionLost: true,
          error: 'Session expirée',
        );
      final storage = _FakeSecureStorage({
        'mystme_onboarding_complete': 'true',
        'mystme_token': 'stale-token',
      });

      await tester.pumpWidget(
        _buildSplashTestApp(notifier: notifier, storage: storage),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Session Recovery Route'), findsOneWidget);
    });

    testWidgets('redirects to home for authenticated returning user',
        (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState())
        ..nextInitState = const AuthState(
          userId: 'user-1',
          pseudo: 'Fox',
        );
      final storage = _FakeSecureStorage({
        'mystme_onboarding_complete': 'true',
        'mystme_token': 'valid-token',
      });

      await tester.pumpWidget(
        _buildSplashTestApp(notifier: notifier, storage: storage),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('Home Route'), findsOneWidget);
    });
  });
}
