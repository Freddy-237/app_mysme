import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/providers/message_provider.dart';
import 'package:mysme/core/providers/socket_service.dart';
import 'package:mysme/features/chat/chat_screen.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());
}

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository() : super(_FakeHttpClient());

  @override
  Future<ConversationDto> getConversation(String id) async {
    return ConversationDto(
      id: id,
      linkId: 'link-id',
      ownerId: 'owner-id',
      anonymousId: 'anonymous-id',
      status: 'active',
      createdAt: DateTime(2026),
    );
  }
}

class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository() : super(_FakeHttpClient());

  @override
  Future<List<MessageDto>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return [];
  }
}

class _FailingSocketService extends SocketService {
  _FailingSocketService() : super(const FlutterSecureStorage());

  int connectCalls = 0;

  @override
  Future<void> connect(String serverUrl) async {
    connectCalls++;
    throw const SocketException('network unavailable');
  }

  @override
  void leaveConversation(String conversationId) {}

  @override
  void disconnect() {}
}

void main() {
  testWidgets('failed socket setup can be retried from its snackbar action',
      (tester) async {
    final socket = _FailingSocketService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider
              .overrideWithValue(_FakeConversationRepository()),
          messageRepositoryProvider
              .overrideWithValue(_FakeMessageRepository()),
          socketServiceProvider.overrideWithValue(socket),
        ],
        child: const MaterialApp(
          home: ChatScreen(conversationId: 'conversation-id'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(socket.connectCalls, 1);
    expect(find.text('Réessayer'), findsOneWidget);

    tester.widget<SnackBar>(find.byType(SnackBar)).action!.onPressed();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(socket.connectCalls, 2);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
