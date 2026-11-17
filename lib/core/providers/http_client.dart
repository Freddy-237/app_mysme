import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void _httpLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

String _describeBody(Map<String, dynamic> body) {
  if (body.isEmpty) return '{}';
  return '{${body.keys.join(', ')}}';
}

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------
const _kTokenKey = 'mystme_token';
const _kUserIdKey = 'mystme_user_id';

// ---------------------------------------------------------------------------
// Timeouts & Retry
// ---------------------------------------------------------------------------
const _kConnectTimeout = Duration(seconds: 15);
const _kReceiveTimeout = Duration(seconds: 15);
const _kMaxRetries = 2;
const _kRetryDelays = [Duration(seconds: 1), Duration(seconds: 3)];

// ---------------------------------------------------------------------------
// Base URL — configurable via --dart-define=API_BASE_URL=http://192.168.x.x:5000
//
// Priority:
//   1. Compile-time override  (flutter run --dart-define=API_BASE_URL=…)
//   2. Fallback → production Railway API
// ---------------------------------------------------------------------------
String get _baseUrl {
  const override = String.fromEnvironment('API_BASE_URL');
  if (override.isNotEmpty) return override;
  return 'https://api-mystme-production.up.railway.app';
}

/// Expose for socket_service.dart to reuse the same base URL.
String get apiBaseUrl => _baseUrl;

// ---------------------------------------------------------------------------
// API Exception
// ---------------------------------------------------------------------------
class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);

  @override
  String toString() => 'ApiException($statusCode): $message';
}

class SessionLostException extends ApiException {
  SessionLostException([
    String message =
        'Session perdue. Restaurez votre compte ou créez une nouvelle identité.',
  ]) : super(message, 401);
}

// ---------------------------------------------------------------------------
// HttpClient — manages JWT, secure storage, and HTTP calls via Dio
// ---------------------------------------------------------------------------
class HttpClient {
  HttpClient(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: _kConnectTimeout,
      receiveTimeout: _kReceiveTimeout,
      contentType: 'application/json',
    ));

    // ── Retry interceptor — retries transient network errors ─────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onError: (DioException e, handler) async {
        final attempt = (e.requestOptions.extra['_retryCount'] as int?) ?? 0;
        if (_canRetryRequest(e.requestOptions, e) && attempt < _kMaxRetries) {
          final delay = _kRetryDelays[attempt];
          _httpLog(
              '[HttpClient.retry] ${e.requestOptions.method} ${e.requestOptions.path} '
              'attempt ${attempt + 1}/$_kMaxRetries after ${delay.inSeconds}s');
          await Future<void>.delayed(delay);
          e.requestOptions.extra['_retryCount'] = attempt + 1;
          try {
            final res = await _dio.fetch(e.requestOptions);
            return handler.resolve(res);
          } on DioException catch (retryError) {
            return handler.reject(retryError);
          }
        }
        return handler.next(e);
      },
    ));

    // ── Auth interceptor — injects JWT ───────────────────────────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        _httpLog('[HttpClient.interceptor.onError] ${e.requestOptions.path} '
            'type=${e.type} status=${e.response?.statusCode} msg=${e.message}');
        // Only a server-confirmed dead session may wipe local credentials.
        // Business 401s (wrong OTP, wrong recovery key…) must never log out.
        if (_isSessionInvalid(e) && !_isReIniting && _token != null) {
          _isReIniting = true;
          try {
            await clearSession();
            _isReIniting = false;
            onSessionLost?.call();
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: SessionLostException(),
              type: e.type,
              response: e.response,
            ));
          } catch (recoveryError) {
            _isReIniting = false;
            return handler.reject(DioException(
              requestOptions: e.requestOptions,
              error: recoveryError,
              type: e.type,
              response: e.response,
            ));
          }
        }
        // Convert DioException → ApiException for uniform handling
        final statusCode = e.response?.statusCode ?? 0;
        final body = e.response?.data;
        String msg;
        if (body is Map && body.containsKey('message')) {
          msg = body['message'] as String;
        } else if (e.type == DioExceptionType.connectionTimeout ||
            e.type == DioExceptionType.receiveTimeout) {
          msg = 'Délai de connexion dépassé';
        } else {
          msg = e.message ?? 'Erreur réseau';
        }
        return handler.reject(DioException(
          requestOptions: e.requestOptions,
          error: ApiException(msg, statusCode),
          type: e.type,
          response: e.response,
        ));
      },
    ));
  }

  final FlutterSecureStorage _storage;
  late final Dio _dio;
  bool _isReIniting = false;

  /// Called when the server rejected our token mid-session (credentials
  /// already wiped). The auth layer uses it to send the user to recovery.
  void Function()? onSessionLost;
  Future<void>? _initFuture;

  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isReady => _token != null && _userId != null;

  /// True when credentials are stored locally, even if the server could not
  /// be reached to validate them yet (offline start).
  bool get hasStoredSession => _token != null && _userId != null;

  /// Expose underlying Dio instance for advanced use (e.g. file uploads).
  Dio get dio => _dio;

  // ── Bootstrap ────────────────────────────────────────────────────────────
  /// Restore a stored session when possible.
  ///
  /// If no session exists locally, a fresh anonymous identity is created.
  /// If a stored session exists but is invalid, [SessionLostException] is
  /// thrown so the UI can offer recovery instead of silently creating a new
  /// identity.
  Future<void> init() {
    if (_initFuture != null) {
      return _initFuture!;
    }

    _initFuture = _doInit().whenComplete(() {
      _initFuture = null;
    });
    return _initFuture!;
  }

  Future<void> _doInit() async {
    _httpLog('[HttpClient.init] reading stored token');
    _token = await _storage.read(key: _kTokenKey);
    _userId = await _storage.read(key: _kUserIdKey);
    _httpLog(
        '[HttpClient.init] stored token=${_token != null ? "present" : "null"}, userId=$_userId');

    if (_token != null) {
      try {
        final me = await get('/identity/me');
        _userId = me['id'] as String;
        await _storage.write(key: _kUserIdKey, value: _userId!);
        _httpLog('[HttpClient.init] token valid');
        await refreshSessionToken();
        return;
      } on ApiException catch (e) {
        // Only a 401 from the server proves the session is dead. Network
        // errors, timeouts, 5xx or a ban (403) must keep the stored session:
        // wiping it would delete an anonymous account forever.
        if (e is SessionLostException || e.statusCode == 401) {
          _httpLog('[HttpClient.init] session rejected by server: $e');
          await clearSession();
          throw SessionLostException();
        }
        _httpLog(
            '[HttpClient.init] cannot validate session now, keeping it: $e');
        rethrow;
      }
    }

    await createAnonymousIdentity();
  }

  /// Exchange the current (still valid) token for a fresh 30-day one.
  /// Called on every start/resume so active users never hit expiry.
  /// Failures are ignored: the current token keeps working.
  Future<void> refreshSessionToken() async {
    if (_token == null) return;
    try {
      final res = await _dio.get('/identity/session-token');
      final fresh = (res.data is Map) ? res.data['token'] as String? : null;
      if (fresh != null && fresh.isNotEmpty) {
        _token = fresh;
        await _storage.write(key: _kTokenKey, value: fresh);
        _httpLog('[HttpClient] session token refreshed');
      }
    } catch (e) {
      _httpLog('[HttpClient] session token refresh skipped: $e');
    }
  }

  Future<void> createAnonymousIdentity() async {
    // Never overwrite an existing account: a stored token means the user has
    // an identity (maybe just offline). Recovery flows clear it explicitly
    // first, via clearSession().
    final storedToken = _token ?? await _storage.read(key: _kTokenKey);
    if (storedToken != null) {
      throw StateError(
        'createAnonymousIdentity refused: an identity is already stored',
      );
    }
    _httpLog('[HttpClient.init] creating new anonymous identity');
    // 'app' identities never expire (web/PWA ones have a 7-day window).
    final res = await _rawPost('/identity/init', {'client': 'app'});
    _token = res['token'] as String;
    _userId = (res['user'] as Map<String, dynamic>)['id'] as String;
    _httpLog('[HttpClient.init] new identity created');

    await _storage.write(key: _kTokenKey, value: _token!);
    await _storage.write(key: _kUserIdKey, value: _userId!);
  }

  /// Clear all stored credentials.
  Future<void> clearSession() async {
    _token = null;
    _userId = null;
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kUserIdKey);
  }

  /// Restore an existing account on a new device using a recovery key.
  Future<void> restoreWithRecoveryKey(String recoveryKey) async {
    final res = await _rawPost('/identity/restore', {
      'recoveryKey': recoveryKey,
    });
    _token = res['token'] as String?;
    _userId = (res['user'] as Map<String, dynamic>)['id'] as String?;

    if (_token == null || _userId == null) {
      throw ApiException('Réponse de restauration invalide', 500);
    }

    await _storage.write(key: _kTokenKey, value: _token!);
    await _storage.write(key: _kUserIdKey, value: _userId!);
  }

  /// Restore an existing account by verified email.
  /// Step 1: request OTP (unauthenticated).
  Future<Map<String, dynamic>> requestEmailRestore(String email) async {
    final res = await _rawPost('/identity/email/restore/request-otp', {
      'email': email,
    });
    return res as Map<String, dynamic>;
  }

  /// Restore an existing account by verified email.
  /// Step 2: verify OTP and swap session (unauthenticated).
  Future<void> verifyEmailRestore(String email, String code) async {
    final res = await _rawPost('/identity/email/restore/verify-otp', {
      'email': email,
      'code': code,
    });
    _token = res['token'] as String?;
    _userId = (res['user'] as Map<String, dynamic>)['id'] as String?;

    if (_token == null || _userId == null) {
      throw ApiException('Réponse de restauration invalide', 500);
    }

    await _storage.write(key: _kTokenKey, value: _token!);
    await _storage.write(key: _kUserIdKey, value: _userId!);
  }

  // ── HTTP verbs ─────────────────────────────────────────────────────────
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    _httpLog('[HttpClient.GET] $path query=$query');
    try {
      final res = await _dio.get(path, queryParameters: query);
      _httpLog('[HttpClient.GET] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      _httpLog(
          '[HttpClient.GET] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    _httpLog('[HttpClient.POST] $path body=${_describeBody(body)}');
    try {
      final res = await _dio.post(path, data: body);
      _httpLog('[HttpClient.POST] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      _httpLog(
          '[HttpClient.POST] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    _httpLog('[HttpClient.PATCH] $path body=${_describeBody(body)}');
    try {
      final res = await _dio.patch(path, data: body);
      _httpLog('[HttpClient.PATCH] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      _httpLog(
          '[HttpClient.PATCH] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> delete(String path) async {
    _httpLog('[HttpClient.DELETE] $path');
    try {
      final res = await _dio.delete(path);
      _httpLog('[HttpClient.DELETE] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      _httpLog(
          '[HttpClient.DELETE] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  /// POST without auth header (for /identity/init before token exists).
  Future<dynamic> _rawPost(String path, Map<String, dynamic> body) async {
    _httpLog('[HttpClient._rawPost] $path body=${_describeBody(body)}');
    try {
      final res = await _dio.post(
        path,
        data: body,
        options: Options(headers: {'Authorization': null}),
      );
      _httpLog('[HttpClient._rawPost] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      _httpLog(
          '[HttpClient._rawPost] $path FAILED: type=${e.type} status=${e.response?.statusCode} msg=${e.message}');
      throw _unwrap(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  /// The server says our token is invalid/expired (see auth.middleware.js).
  /// Falls back to "401 on /identity/me" for backends without the code.
  static bool _isSessionInvalid(DioException e) {
    if (e.response?.statusCode != 401) return false;
    final body = e.response?.data;
    final code = body is Map ? body['code'] : null;
    if (code == 'AUTH_INVALID' || code == 'AUTH_REQUIRED') return true;
    return code == null && e.requestOptions.path == '/identity/me';
  }

  /// Whether a DioException is a transient network error worth retrying.
  static bool _isRetryable(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode ?? 0;
        return code == 502 || code == 503 || code == 504;
      default:
        return false;
    }
  }

  static bool _canRetryRequest(RequestOptions requestOptions, DioException e) {
    final method = requestOptions.method.toUpperCase();
    final isSafeMethod =
        method == 'GET' || method == 'HEAD' || method == 'OPTIONS';
    return isSafeMethod && _isRetryable(e);
  }

  /// Unwraps a DioException into an ApiException for callers.
  ApiException _unwrap(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    final code = e.response?.statusCode ?? 0;
    return ApiException(e.message ?? 'Erreur réseau', code);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Secure storage instance (override in tests).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => const FlutterSecureStorage(),
);

/// The singleton HTTP client — every repository reads from here.
final httpClientProvider = Provider<HttpClient>((ref) {
  return HttpClient(ref.watch(secureStorageProvider));
});
