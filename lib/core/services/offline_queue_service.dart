import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysme/core/providers/http_client.dart';

void _offlineQueueLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

// ---------------------------------------------------------------------------
// Pending message model
// ---------------------------------------------------------------------------

class PendingMessage {
  const PendingMessage({
    required this.conversationId,
    required this.content,
    this.replyToMessageId,
    required this.queuedAt,
  });

  final String conversationId;
  final String content;
  final String? replyToMessageId;
  final DateTime queuedAt;

  Map<String, dynamic> toJson() => {
        'conversationId': conversationId,
        'content': content,
        if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
        'queuedAt': queuedAt.toIso8601String(),
      };

  factory PendingMessage.fromJson(Map<String, dynamic> json) => PendingMessage(
        conversationId: json['conversationId'] as String,
        content: json['content'] as String,
        replyToMessageId: json['replyToMessageId'] as String?,
        queuedAt: DateTime.parse(json['queuedAt'] as String),
      );
}

// ---------------------------------------------------------------------------
// Offline Queue Service
// ---------------------------------------------------------------------------

const _kStorageKey = 'mystme_offline_queue_encrypted';
const _kLegacyStorageKey = 'mystme_offline_queue';
const _kEncryptionKey = 'mystme_offline_queue_encryption_key';

class OfflineQueueService {
  OfflineQueueService(this._client, this._secureStorage);
  final HttpClient _client;
  final FlutterSecureStorage _secureStorage;
  final AesGcm _cipher = AesGcm.with256bits();

  final List<PendingMessage> _queue = [];
  bool _flushing = false;
  SecretKey? _cachedEncryptionKey;
  Future<SecretKey>? _encryptionKeyFuture;

  List<PendingMessage> get pending => List.unmodifiable(_queue);
  int get length => _queue.length;

  // ── Persistence ─────────────────────────────────────────────────────────

  /// Load queued messages from local storage (call once at startup).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final encrypted = prefs.getString(_kStorageKey);
    if (encrypted != null && encrypted.isNotEmpty) {
      try {
        final payload = jsonDecode(encrypted) as Map<String, dynamic>;
        if (payload['version'] != 1) {
          throw const FormatException('Unsupported offline queue version');
        }
        final box = SecretBox(
          base64Decode(payload['cipherText'] as String),
          nonce: base64Decode(payload['nonce'] as String),
          mac: Mac(base64Decode(payload['mac'] as String)),
        );
        final clearText = await _cipher.decrypt(
          box,
          secretKey: await _getEncryptionKey(createIfMissing: false),
        );
        _queue
          ..clear()
          ..addAll(_decodeQueue(utf8.decode(clearText)));
      } catch (error) {
        _offlineQueueLog(
          '[OfflineQueueService] Dropping unreadable encrypted queue: $error',
        );
        _queue.clear();
        await prefs.remove(_kStorageKey);
      }
      await prefs.remove(_kLegacyStorageKey);
      return;
    }

    final legacyRaw = prefs.getString(_kLegacyStorageKey);
    if (legacyRaw == null || legacyRaw.isEmpty) return;
    try {
      _queue.clear();
      _queue.addAll(_decodeQueue(legacyRaw));
    } catch (error) {
      _offlineQueueLog(
        '[OfflineQueueService] Dropping corrupt legacy queue data: $error',
      );
      _queue.clear();
      await prefs.remove(_kLegacyStorageKey);
      return;
    }
    await _persist();
    await prefs.remove(_kLegacyStorageKey);
  }

  List<PendingMessage> _decodeQueue(String raw) {
    final list = jsonDecode(raw) as List;
    return list
        .map((item) => PendingMessage.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SecretKey> _getEncryptionKey({bool createIfMissing = true}) async {
    final cached = _cachedEncryptionKey;
    if (cached != null) return cached;

    if (!createIfMissing) return _readEncryptionKey();

    final pending = _encryptionKeyFuture;
    if (pending != null) return pending;

    final future = _loadOrCreateEncryptionKey();
    _encryptionKeyFuture = future;
    try {
      return _cachedEncryptionKey = await future;
    } catch (_) {
      _encryptionKeyFuture = null;
      rethrow;
    }
  }

  Future<SecretKey> _readEncryptionKey() async {
    final stored = await _secureStorage.read(key: _kEncryptionKey);
    if (stored == null) {
      throw StateError('Offline queue encryption key is missing');
    }

    return _cachedEncryptionKey = await _decodeEncryptionKey(stored);
  }

  Future<SecretKey> _loadOrCreateEncryptionKey() async {
    final stored = await _secureStorage.read(key: _kEncryptionKey);
    if (stored != null) return _decodeEncryptionKey(stored);

    final key = await _cipher.newSecretKey();
    final keyBytes = await key.extractBytes();
    await _secureStorage.write(
      key: _kEncryptionKey,
      value: base64Encode(keyBytes),
    );
    return SecretKey(keyBytes);
  }

  Future<SecretKey> _decodeEncryptionKey(String stored) async {
    late final List<int> keyBytes;
    try {
      keyBytes = base64Decode(stored);
    } on FormatException {
      await _secureStorage.delete(key: _kEncryptionKey);
      throw const FormatException('Invalid offline queue encryption key');
    }
    if (keyBytes.length != 32) {
      await _secureStorage.delete(key: _kEncryptionKey);
      throw const FormatException('Invalid offline queue encryption key');
    }
    return SecretKey(keyBytes);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_queue.isEmpty) {
      await prefs.remove(_kStorageKey);
    } else {
      final box = await _cipher.encrypt(
        utf8.encode(jsonEncode(_queue.map((m) => m.toJson()).toList())),
        secretKey: await _getEncryptionKey(),
      );
      await prefs.setString(
        _kStorageKey,
        jsonEncode({
          'version': 1,
          'nonce': base64Encode(box.nonce),
          'cipherText': base64Encode(box.cipherText),
          'mac': base64Encode(box.mac.bytes),
        }),
      );
    }
  }

  // ── Enqueue ─────────────────────────────────────────────────────────────

  /// Add a message to the offline queue and persist.
  Future<void> enqueue(PendingMessage msg) async {
    _queue.add(msg);
    await _persist();
  }

  // ── Flush ───────────────────────────────────────────────────────────────

  /// Try to send all queued messages. Returns the number successfully sent.
  /// Silently keeps failed items in the queue for the next attempt.
  Future<int> flush() async {
    if (_flushing || _queue.isEmpty) return 0;
    _flushing = true;

    try {
      int sent = 0;
      final toRetry = <PendingMessage>[];

      for (final msg in List.of(_queue)) {
        try {
          await _client.post('/message', {
            'conversationId': msg.conversationId,
            'content': msg.content,
            if (msg.replyToMessageId != null)
              'replyToMessageId': msg.replyToMessageId,
          });
          sent++;
        } catch (error) {
          _offlineQueueLog(
            '[OfflineQueueService] Flush failed for ${msg.conversationId}: $error',
          );
          toRetry.add(msg);
        }
      }

      _queue
        ..clear()
        ..addAll(toRetry);
      await _persist();
      return sent;
    } finally {
      _flushing = false;
    }
  }

  /// Discard messages older than [maxAge] (default 24 h).
  Future<void> pruneOld([Duration maxAge = const Duration(hours: 24)]) async {
    final cutoff = DateTime.now().subtract(maxAge);
    _queue.removeWhere((m) => m.queuedAt.isBefore(cutoff));
    await _persist();
  }

  /// Prune expired queued items before attempting a reconnect flush.
  Future<int> pruneAndFlush(
      [Duration maxAge = const Duration(hours: 24)]) async {
    await pruneOld(maxAge);
    return flush();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final client = ref.watch(httpClientProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  return OfflineQueueService(client, secureStorage);
});
