import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/providers/socket_service.dart';
import 'package:mysme/features/chat/chat_screen.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());
}

class _FailingConversationRepository extends ConversationRepository {
  _FailingConversationRepository() : super(_FakeHttpClient());

  int getConversationCalls = 0;

  @override
  Future<ConversationDto> getConversation(String id) async {
    getConversationCalls++;
    throw StateError('simulated network error');
  }
}

class _FakeSocketService extends SocketService {
  _FakeSocketService() : super(const FlutterSecureStorage());

  @override
  void leaveConversation(String conversationId) {}

  @override
  void disconnect() {}
}

void main() {
  testWidgets('failed conversation load shows a retry action', (tester) async {
    final repository = _FailingConversationRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(repository),
          socketServiceProvider.overrideWithValue(_FakeSocketService()),
        ],
        child: const MaterialApp(
          home: ChatScreen(conversationId: 'conversation-id'),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Impossible de charger cette discussion'),
      findsOneWidget,
    );
    expect(find.text('Réessayer'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(repository.getConversationCalls, 1);

    await tester.tap(find.text('Réessayer'));
    await tester.pump();
    await tester.pump();

    expect(repository.getConversationCalls, 2);
    expect(find.text('Réessayer'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
