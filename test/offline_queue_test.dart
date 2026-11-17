import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/services/offline_queue_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());

  final List<Map<String, dynamic>> sentBodies = [];

  @override
  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    sentBodies.add({'path': path, 'body': body});
    return const {'ok': true};
  }
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
  }) async =>
      _values[key];

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
    } else {
      _values[key] = value;
    }
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

void main() {
  group('PendingMessage', () {
    test('serializes and deserializes correctly', () {
      final msg = PendingMessage(
        conversationId: 'conv1',
        content: 'Hello offline',
        replyToMessageId: 'reply1',
        queuedAt: DateTime(2025, 1, 15, 10, 30),
      );

      final json = msg.toJson();
      expect(json['conversationId'], 'conv1');
      expect(json['content'], 'Hello offline');
      expect(json['replyToMessageId'], 'reply1');

      final restored = PendingMessage.fromJson(json);
      expect(restored.conversationId, msg.conversationId);
      expect(restored.content, msg.content);
      expect(restored.replyToMessageId, msg.replyToMessageId);
      expect(restored.queuedAt, msg.queuedAt);
    });

    test('serializes without replyToMessageId', () {
      final msg = PendingMessage(
        conversationId: 'conv2',
        content: 'No reply',
        queuedAt: DateTime.now(),
      );

      final json = msg.toJson();
      expect(json.containsKey('replyToMessageId'), isFalse);

      final restored = PendingMessage.fromJson(json);
      expect(restored.replyToMessageId, isNull);
    });
  });

  group('OfflineQueueService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('pruneOld removes stale queued messages from storage', () async {
      final stale = PendingMessage(
        conversationId: 'conv-old',
        content: 'expired',
        queuedAt: DateTime.now().subtract(const Duration(days: 2)),
      );
      final fresh = PendingMessage(
        conversationId: 'conv-new',
        content: 'fresh',
        queuedAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'mystme_offline_queue': jsonEncode([stale.toJson(), fresh.toJson()]),
      });

      final service = OfflineQueueService(
        _FakeHttpClient(),
        _FakeSecureStorage({}),
      );
      await service.load();
      await service.pruneOld(const Duration(hours: 24));

      expect(
          service.pending.map((m) => m.conversationId).toList(), ['conv-new']);
    });

    test('pruneAndFlush sends only fresh queued messages', () async {
      final client = _FakeHttpClient();
      final service = OfflineQueueService(client, _FakeSecureStorage({}));

      await service.enqueue(PendingMessage(
        conversationId: 'conv-old',
        content: 'expired',
        queuedAt: DateTime.now().subtract(const Duration(days: 2)),
      ));
      await service.enqueue(PendingMessage(
        conversationId: 'conv-new',
        content: 'fresh',
        queuedAt: DateTime.now(),
      ));

      final sent = await service.pruneAndFlush(const Duration(hours: 24));

      expect(sent, 1);
      expect(client.sentBodies, hasLength(1));
      expect(client.sentBodies.single['path'], '/message');
      expect(
        (client.sentBodies.single['body']
            as Map<String, dynamic>)['conversationId'],
        'conv-new',
      );
      expect(service.pending, isEmpty);
    });

    test('persists queued message contents encrypted and restores them',
        () async {
      final storage = _FakeSecureStorage({});
      final client = _FakeHttpClient();
      final service = OfflineQueueService(client, storage);
      await service.enqueue(PendingMessage(
        conversationId: 'conv-private',
        content: 'private message text',
        queuedAt: DateTime.now(),
      ));

      final prefs = await SharedPreferences.getInstance();
      final encrypted = prefs.getString('mystme_offline_queue_encrypted');
      expect(encrypted, isNotNull);
      expect(encrypted, isNot(contains('private message text')));
      expect(prefs.getString('mystme_offline_queue'), isNull);

      final restored = OfflineQueueService(client, storage);
      await restored.load();

      expect(restored.pending.single.content, 'private message text');
    });

    test('migrates the legacy plaintext queue to encrypted storage', () async {
      final legacyMessage = PendingMessage(
        conversationId: 'conv-legacy',
        content: 'legacy private text',
        queuedAt: DateTime.now(),
      );
      SharedPreferences.setMockInitialValues({
        'mystme_offline_queue': jsonEncode([legacyMessage.toJson()]),
      });
      final prefs = await SharedPreferences.getInstance();
      final service = OfflineQueueService(
        _FakeHttpClient(),
        _FakeSecureStorage({}),
      );

      await service.load();

      expect(service.pending.single.content, 'legacy private text');
      expect(prefs.getString('mystme_offline_queue'), isNull);
      expect(
        prefs.getString('mystme_offline_queue_encrypted'),
        isNot(contains('legacy private text')),
      );
    });
  });
}
