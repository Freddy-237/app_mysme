import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ---------------------------------------------------------------------------
// Keys
// ---------------------------------------------------------------------------
const _kTokenKey = 'mystme_token';
const _kUserIdKey = 'mystme_user_id';

// ---------------------------------------------------------------------------
// Timeouts
// ---------------------------------------------------------------------------
const _kConnectTimeout = Duration(seconds: 15);
const _kReceiveTimeout = Duration(seconds: 15);

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

    // ── Auth interceptor — injects JWT ───────────────────────────────────
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        debugPrint('[HttpClient.interceptor.onError] ${e.requestOptions.path} '
            'type=${e.type} status=${e.response?.statusCode} msg=${e.message}');
        // Auto re-init on 401 (expired / invalid token)
        if (e.response?.statusCode == 401 && !_isReIniting) {
          _isReIniting = true;
          try {
            await clearSession();
            await init();
            // Retry original request with fresh token
            final opts = e.requestOptions;
            opts.headers['Authorization'] = 'Bearer $_token';
            final retryRes = await _dio.fetch(opts);
            _isReIniting = false;
            return handler.resolve(retryRes);
          } catch (_) {
            _isReIniting = false;
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

  String? _token;
  String? _userId;

  String? get token => _token;
  String? get userId => _userId;
  bool get isReady => _token != null && _userId != null;

  /// Expose underlying Dio instance for advanced use (e.g. file uploads).
  Dio get dio => _dio;

  // ── Bootstrap ────────────────────────────────────────────────────────────
  /// Load stored token or create a new anonymous identity.
  Future<void> init() async {
    debugPrint('[HttpClient.init] reading stored token…');
    _token = await _storage.read(key: _kTokenKey);
    _userId = await _storage.read(key: _kUserIdKey);
    debugPrint(
        '[HttpClient.init] stored token=${_token != null ? "present" : "null"}, userId=$_userId');

    if (_token != null) {
      try {
        final me = await get('/identity/me');
        _userId = me['id'] as String;
        debugPrint('[HttpClient.init] token valid — userId=$_userId');
        return;
      } catch (e) {
        debugPrint('[HttpClient.init] token invalid, re-init: $e');
        _token = null;
        _userId = null;
      }
    }

    // No token → get a new anonymous identity
    debugPrint('[HttpClient.init] creating new anonymous identity…');
    final res = await _rawPost('/identity/init', {});
    _token = res['token'] as String;
    _userId = (res['user'] as Map<String, dynamic>)['id'] as String;
    debugPrint('[HttpClient.init] new identity created — userId=$_userId');

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

  // ── HTTP verbs ─────────────────────────────────────────────────────────
  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    debugPrint('[HttpClient.GET] $path query=$query');
    try {
      final res = await _dio.get(path, queryParameters: query);
      debugPrint('[HttpClient.GET] $path → ${res.statusCode}');
      if (path.contains('/conversation/mine')) {
        debugPrint('[HttpClient.GET] /conversation/mine BODY: ${res.data}');
      }
      return res.data;
    } on DioException catch (e) {
      debugPrint(
          '[HttpClient.GET] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    debugPrint('[HttpClient.POST] $path body=$body');
    try {
      final res = await _dio.post(path, data: body);
      debugPrint('[HttpClient.POST] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      debugPrint(
          '[HttpClient.POST] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> patch(String path, Map<String, dynamic> body) async {
    debugPrint('[HttpClient.PATCH] $path body=$body');
    try {
      final res = await _dio.patch(path, data: body);
      debugPrint('[HttpClient.PATCH] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      debugPrint(
          '[HttpClient.PATCH] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  Future<dynamic> delete(String path) async {
    debugPrint('[HttpClient.DELETE] $path');
    try {
      final res = await _dio.delete(path);
      debugPrint('[HttpClient.DELETE] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      debugPrint(
          '[HttpClient.DELETE] $path FAILED: ${e.response?.statusCode} ${e.message}');
      throw _unwrap(e);
    }
  }

  /// POST without auth header (for /identity/init before token exists).
  Future<dynamic> _rawPost(String path, Map<String, dynamic> body) async {
    debugPrint('[HttpClient._rawPost] $path body=$body');
    try {
      final res = await _dio.post(
        path,
        data: body,
        options: Options(headers: {'Authorization': null}),
      );
      debugPrint('[HttpClient._rawPost] $path → ${res.statusCode}');
      return res.data;
    } on DioException catch (e) {
      debugPrint(
          '[HttpClient._rawPost] $path FAILED: type=${e.type} status=${e.response?.statusCode} msg=${e.message}');
      throw _unwrap(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
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
