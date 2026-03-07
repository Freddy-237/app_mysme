import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysme/core/providers/http_client.dart';

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

const _kStorageKey = 'mystme_offline_queue';

class OfflineQueueService {
  OfflineQueueService(this._client);
  final HttpClient _client;

  final List<PendingMessage> _queue = [];
  bool _flushing = false;

  List<PendingMessage> get pending => List.unmodifiable(_queue);
  int get length => _queue.length;

  // ── Persistence ─────────────────────────────────────────────────────────

  /// Load queued messages from local storage (call once at startup).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kStorageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List;
      _queue.clear();
      for (final item in list) {
        _queue.add(PendingMessage.fromJson(item as Map<String, dynamic>));
      }
    } catch (_) {
      // Corrupt data — discard
      await prefs.remove(_kStorageKey);
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_queue.isEmpty) {
      await prefs.remove(_kStorageKey);
    } else {
      await prefs.setString(
        _kStorageKey,
        jsonEncode(_queue.map((m) => m.toJson()).toList()),
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
      } catch (_) {
        toRetry.add(msg);
      }
    }

    _queue
      ..clear()
      ..addAll(toRetry);
    await _persist();
    _flushing = false;
    return sent;
  }

  /// Discard messages older than [maxAge] (default 24 h).
  Future<void> pruneOld([Duration maxAge = const Duration(hours: 24)]) async {
    final cutoff = DateTime.now().subtract(maxAge);
    _queue.removeWhere((m) => m.queuedAt.isBefore(cutoff));
    await _persist();
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final offlineQueueProvider = Provider<OfflineQueueService>((ref) {
  final client = ref.watch(httpClientProvider);
  return OfflineQueueService(client);
});
