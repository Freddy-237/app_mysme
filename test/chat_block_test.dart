import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/providers/message_provider.dart';
import 'package:mysme/core/providers/socket_service.dart';
import 'package:mysme/features/chat/chat_screen.dart';
import 'package:mysme/features/chat/widgets/chat_input_bar.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());
}

ConversationDto _conversation(String status) => ConversationDto.fromJson({
      'id': 'c1',
      'link_id': 'l1',
      'owner_id': 'owner',
      'anonymous_id': 'anon',
      'status': status,
      'created_at': '2026-11-18T10:00:00.000Z',
      'anonymous_pseudo': 'ShadowFox_1234',
    });

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository(this.current, {this.failBlock = false})
      : super(_FakeHttpClient());

  ConversationDto current;
  final bool failBlock;
  int blockCalls = 0;

  @override
  Future<ConversationDto> getConversation(String id) async => current;

  @override
  Future<ConversationDto> blockConversation(String id) async {
    blockCalls++;
    if (failBlock) throw ApiException('Erreur serveur', 500);
    current = _conversation('blocked');
    return current;
  }
}

class _FakeMessageRepository extends MessageRepository {
  _FakeMessageRepository() : super(_FakeHttpClient());

  @override
  Future<List<MessageDto>> getMessages(String conversationId,
          {int limit = 50, int offset = 0}) async =>
      const [];
}

class _FakeSocketService extends SocketService {
  _FakeSocketService() : super(const FlutterSecureStorage());

  @override
  Future<void> connect(String serverUrl) async {}

  @override
  void joinConversation(String conversationId) {}

  @override
  void leaveConversation(String conversationId) {}

  @override
  void disconnect() {}
}

Future<void> _pumpChat(WidgetTester tester, _FakeConversationRepository repo) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(repo),
        messageRepositoryProvider.overrideWithValue(_FakeMessageRepository()),
        socketServiceProvider.overrideWithValue(_FakeSocketService()),
      ],
      child: const MaterialApp(home: ChatScreen(conversationId: 'c1')),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.more_vert).first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('blocking asks for confirmation, then replaces the input bar', (tester) async {
    final repo = _FakeConversationRepository(_conversation('active'));
    await _pumpChat(tester, repo);
    expect(find.byType(ChatInputBar), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(find.text('Bloquer cette discussion'));
    await tester.pumpAndSettle();
    expect(find.text('Bloquer cette discussion ?'), findsOneWidget);

    // Cancelling does nothing.
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(repo.blockCalls, 0);
    expect(find.byType(ChatInputBar), findsOneWidget);

    await _openMenu(tester);
    await tester.tap(find.text('Bloquer cette discussion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquer'));
    await tester.pumpAndSettle();

    expect(repo.blockCalls, 1);
    expect(find.byType(ChatInputBar), findsNothing);
    expect(find.text('Discussion bloquée. Plus personne ne peut y écrire.'), findsOneWidget);

    // Once blocked, the menu no longer offers to block.
    await _openMenu(tester);
    expect(find.text('Bloquer cette discussion'), findsNothing);
    expect(find.text('Signaler cet utilisateur'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    // Let the screen's delayed work (retries, snack bars) run out.
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('an already blocked conversation opens without input bar', (tester) async {
    await _pumpChat(tester, _FakeConversationRepository(_conversation('blocked')));
    expect(find.byType(ChatInputBar), findsNothing);
    expect(find.text('Discussion bloquée. Plus personne ne peut y écrire.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the screen's delayed work (retries, snack bars) run out.
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('a failed block keeps the conversation usable and says so', (tester) async {
    final repo = _FakeConversationRepository(_conversation('active'), failBlock: true);
    await _pumpChat(tester, repo);

    await _openMenu(tester);
    await tester.tap(find.text('Bloquer cette discussion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bloquer'));
    await tester.pumpAndSettle();

    expect(repo.blockCalls, 1);
    expect(find.byType(ChatInputBar), findsOneWidget);
    expect(find.text('Discussion bloquée. Plus personne ne peut y écrire.'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    // Let the screen's delayed work (retries, snack bars) run out.
    await tester.pump(const Duration(minutes: 1));
  });
}
