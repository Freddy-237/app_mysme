import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/services/offline_queue_service.dart';

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
}
