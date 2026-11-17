import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/features/chat/chat_send_guard.dart';

void main() {
  group('ChatSendGuard', () {
    test('allows a normal message', () {
      final result = ChatSendGuard.validate(
        rawText: 'Bonjour',
        now: DateTime(2026, 3, 11, 10, 0, 0),
      );

      expect(result, isNull);
    });

    test('blocks messages that are too long', () {
      final text = 'a' * (ChatSendGuard.maxMessageLength + 1);

      final result = ChatSendGuard.validate(
        rawText: text,
        now: DateTime(2026, 3, 11, 10, 0, 0),
      );

      expect(result, contains('Message trop long'));
    });

    test('blocks immediate duplicate messages', () {
      final sentAt = DateTime(2026, 3, 11, 10, 0, 0);

      final result = ChatSendGuard.validate(
        rawText: 'Salut',
        now: sentAt.add(const Duration(seconds: 3)),
        lastSentAt: sentAt,
        lastSentContent: 'Salut',
      );

      expect(result, 'Message déjà envoyé il y a un instant');
    });

    test('blocks burst sending even with different content', () {
      final sentAt = DateTime(2026, 3, 11, 10, 0, 0);

      final result = ChatSendGuard.validate(
        rawText: 'Deuxième message',
        now: sentAt.add(const Duration(milliseconds: 300)),
        lastSentAt: sentAt,
        lastSentContent: 'Premier message',
      );

      expect(result, 'Tu envoies trop vite');
    });

    test('allows a normal media action', () {
      final result = ChatSendGuard.validateAction(
        actionSignature: 'image:/tmp/pic.jpg',
        now: DateTime(2026, 3, 11, 10, 0, 0),
      );

      expect(result, isNull);
    });

    test('blocks duplicate media action in duplicate window', () {
      final sentAt = DateTime(2026, 3, 11, 10, 0, 0);

      final result = ChatSendGuard.validateAction(
        actionSignature: 'audio:/tmp/note.aac',
        now: sentAt.add(const Duration(seconds: 2)),
        lastSentAt: sentAt,
        lastSentContent: 'audio:/tmp/note.aac',
      );

      expect(result, 'Envoi déjà lancé il y a un instant');
    });
  });
}
