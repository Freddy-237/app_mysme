// Regression tests: an anonymous account must never be wiped by a transient
// error or by a "business" 401 (wrong OTP / recovery key). Only a server
// answer saying the token itself is invalid may clear the session.
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/http_client.dart';

typedef _Responder = ResponseBody Function(RequestOptions options);

/// Fake transport: answers each request from a path → responder map.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.routes);

  final Map<String, _Responder> routes;
  final List<String> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add('${options.method} ${options.path}');
    final responder = routes[options.path];
    if (responder == null) {
      throw StateError('Unexpected request ${options.method} ${options.path}');
    }
    return responder(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

const _storage = FlutterSecureStorage();

Future<HttpClient> _clientWith(Map<String, _Responder> routes,
    {Map<String, String> stored = const {}}) async {
  FlutterSecureStorage.setMockInitialValues(Map.of(stored));
  final client = HttpClient(_storage);
  client.dio.httpClientAdapter = _FakeAdapter(routes);
  return client;
}

const _existingSession = {
  'mystme_token': 'old-token',
  'mystme_user_id': 'user-1',
};

void main() {
  test('server error at startup keeps the stored session', () async {
    final client = await _clientWith({
      '/identity/me': (_) => _json(500, {'message': 'boom'}),
    }, stored: _existingSession);

    await expectLater(client.init(), throwsA(isA<ApiException>()));

    expect(client.hasStoredSession, isTrue);
    expect(await _storage.read(key: 'mystme_token'), 'old-token');
    expect(await _storage.read(key: 'mystme_user_id'), 'user-1');
  });

  test('network failure at startup keeps the stored session', () async {
    final client = await _clientWith({
      '/identity/me': (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ),
    }, stored: _existingSession);

    await expectLater(client.init(), throwsA(isA<ApiException>()));

    expect(await _storage.read(key: 'mystme_token'), 'old-token');
  }, timeout: const Timeout(Duration(seconds: 20)));

  test('banned account (403) at startup does not wipe the session', () async {
    final client = await _clientWith({
      '/identity/me': (_) =>
          _json(403, {'message': 'Compte suspendu', 'code': 'ACCOUNT_BANNED'}),
    }, stored: _existingSession);

    await expectLater(client.init(), throwsA(isA<ApiException>()));
    expect(await _storage.read(key: 'mystme_token'), 'old-token');
  });

  test('token rejected by the server at startup → SessionLostException',
      () async {
    final client = await _clientWith({
      '/identity/me': (_) =>
          _json(401, {'message': 'Token expiré', 'code': 'AUTH_INVALID'}),
    }, stored: _existingSession);

    await expectLater(client.init(), throwsA(isA<SessionLostException>()));
    expect(await _storage.read(key: 'mystme_token'), isNull);
  });

  test('valid session at startup is refreshed with a new token', () async {
    final client = await _clientWith({
      '/identity/me': (_) => _json(200, {'id': 'user-1'}),
      '/identity/session-token': (_) => _json(200, {'token': 'fresh-token'}),
    }, stored: _existingSession);

    await client.init();

    expect(client.token, 'fresh-token');
    expect(await _storage.read(key: 'mystme_token'), 'fresh-token');
  });

  test('wrong OTP (business 401 without AUTH code) keeps the session',
      () async {
    final client = await _clientWith({
      '/identity/me': (_) => _json(200, {'id': 'user-1'}),
      '/identity/session-token': (_) => _json(200, {'token': 'old-token'}),
      '/identity/email/verify-otp': (_) =>
          _json(401, {'message': 'Code OTP invalide'}),
    }, stored: _existingSession);
    var sessionLostCalls = 0;
    client.onSessionLost = () => sessionLostCalls++;
    await client.init();

    await expectLater(
      client
          .post('/identity/email/verify-otp', {'email': 'a@b.c', 'code': '1'}),
      throwsA(isA<ApiException>()
          .having((e) => e is SessionLostException, 'session lost', isFalse)),
    );

    expect(client.isReady, isTrue);
    expect(await _storage.read(key: 'mystme_token'), 'old-token');
    expect(sessionLostCalls, 0);
  });

  test('token rejected mid-session clears it and notifies the app', () async {
    final client = await _clientWith({
      '/identity/me': (_) => _json(200, {'id': 'user-1'}),
      '/identity/session-token': (_) => _json(200, {'token': 'old-token'}),
      '/conversation/mine': (_) =>
          _json(401, {'message': 'Token expiré', 'code': 'AUTH_INVALID'}),
    }, stored: _existingSession);
    var sessionLostCalls = 0;
    client.onSessionLost = () => sessionLostCalls++;
    await client.init();

    await expectLater(
      client.get('/conversation/mine'),
      throwsA(isA<SessionLostException>()),
    );
    expect(sessionLostCalls, 1);
    expect(await _storage.read(key: 'mystme_token'), isNull);
  });

  test('createAnonymousIdentity refuses to overwrite a stored identity',
      () async {
    final client = await _clientWith({
      '/identity/init': (_) => _json(201, {
            'token': 'new-token',
            'user': {'id': 'user-2'},
          }),
    }, stored: _existingSession);

    await expectLater(client.createAnonymousIdentity(), throwsStateError);
    expect(await _storage.read(key: 'mystme_token'), 'old-token');
  });

  test('first launch (nothing stored) creates an identity', () async {
    final client = await _clientWith({
      '/identity/init': (_) => _json(201, {
            'token': 'new-token',
            'user': {'id': 'user-2'},
          }),
    });

    await client.init();

    expect(client.userId, 'user-2');
    expect(await _storage.read(key: 'mystme_token'), 'new-token');
  });
}
