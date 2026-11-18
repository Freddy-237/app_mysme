import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mysme/core/providers/http_client.dart';

void _transferLog(String message) {
  if (kDebugMode) debugPrint(message);
}

/// Result of a successful PWA → app transfer.
class TransferResult {
  const TransferResult(this.conversationIds);
  final List<String> conversationIds;
}

/// Moves a web (PWA) identity into this app identity.
///
/// The one-time code reaches the app in three ways:
///  * Android: Play Store install referrer (`transfer=ABCD-2345`), read once;
///  * deep link `mystme://transfer?code=ABCD-2345` (app already installed);
///  * manual entry / paste (`MYSTME:ABCD-2345` copied by the PWA) — iOS path.
class TransferService {
  TransferService(
    this._client,
    this._storage, {
    Future<String?> Function()? installReferrerReader,
    bool? isAndroid,
  })  : _readInstallReferrer = installReferrerReader ?? _defaultReferrerReader,
        _isAndroid = isAndroid ??
            (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  final HttpClient _client;
  final FlutterSecureStorage _storage;
  final Future<String?> Function() _readInstallReferrer;
  final bool _isAndroid;

  static const _kReferrerCheckedKey = 'mystme_install_referrer_checked';
  static const _alphabet = 'A-HJ-NP-Z2-9'; // matches the backend alphabet
  static final _prefixed =
      RegExp('MYSTME[:\\s-]*([$_alphabet]{4})-?([$_alphabet]{4})');
  static final _bare = RegExp('^([$_alphabet]{4})-?([$_alphabet]{4})\$');

  static Future<String?> _defaultReferrerReader() async {
    final details = await AndroidPlayInstallReferrer.installReferrer;
    return details.installReferrer;
  }

  /// Extracts a transfer code from pasted text ("MYSTME:ABCD-2345",
  /// "abcd2345", "transfer=ABCD-2345"…). Returns "ABCD-2345" or null.
  static String? extractCode(String? text) {
    if (text == null) return null;
    final upper = text.trim().toUpperCase();
    if (upper.isEmpty) return null;

    final referrerValue = upper.startsWith('TRANSFER=')
        ? upper.substring('TRANSFER='.length)
        : upper;
    final match =
        _prefixed.firstMatch(referrerValue) ?? _bare.firstMatch(referrerValue);
    if (match == null) return null;
    return '${match.group(1)}-${match.group(2)}';
  }

  /// Parses the Play install referrer ("transfer=ABCD-2345&utm_source=…").
  static String? codeFromReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty) return null;
    try {
      final params = Uri.splitQueryString(referrer);
      return extractCode(params['transfer']);
    } catch (_) {
      return null;
    }
  }

  /// Android only, at most once per install: the code the PWA put in the
  /// store link. Never throws (no Play services, iOS…).
  Future<String?> readInstallReferrerCodeOnce() async {
    if (!_isAndroid) return null;
    try {
      if (await _storage.read(key: _kReferrerCheckedKey) == 'true') return null;
      await _storage.write(key: _kReferrerCheckedKey, value: 'true');
      final referrer = await _readInstallReferrer();
      final code = codeFromReferrer(referrer);
      _transferLog('[TransferService] install referrer code=${code != null}');
      return code;
    } catch (error) {
      _transferLog('[TransferService] install referrer unavailable: $error');
      return null;
    }
  }

  /// Absorb the web identity behind [code] into the current app identity.
  Future<TransferResult> claim(String code) async {
    final normalized = extractCode(code) ?? code.trim();
    final res = await _client.post('/identity/transfer/claim', {
      'code': normalized,
    });
    final ids =
        (res is Map ? res['conversationIds'] : null) as List? ?? const [];
    return TransferResult(ids.map((e) => e.toString()).toList());
  }
}

final transferServiceProvider = Provider<TransferService>((ref) {
  return TransferService(
    ref.watch(httpClientProvider),
    ref.watch(secureStorageProvider),
  );
});
