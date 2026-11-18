import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/conversation_provider.dart';
import 'package:mysme/core/providers/http_client.dart';

class _FakeHttpClient extends HttpClient {
  _FakeHttpClient() : super(const FlutterSecureStorage());
}

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository() : super(_FakeHttpClient());

  final Map<int, ConversationPageDto> pagesByOffset = {};
  final Map<String, ConversationDto> conversationsById = {};
  final Map<String, Completer<ConversationDto>> pendingConversationById = {};
  final Map<String, int> getConversationCalls = {};
  int getMyConversationsCalls = 0;
  bool allowAuthenticatedSession = true;

  @override
  bool get hasAuthenticatedSession => allowAuthenticatedSession;

  @override
  Future<ConversationPageDto> getMyConversations({
    int limit = 30,
    int offset = 0,
  }) async {
    getMyConversationsCalls++;
    return pagesByOffset[offset] ??
        const ConversationPageDto(
          items: [],
          hasMore: false,
          nextOffset: null,
        );
  }

  @override
  Future<ConversationDto> getConversation(String id) async {
    getConversationCalls[id] = (getConversationCalls[id] ?? 0) + 1;
    final pending = pendingConversationById[id];
    if (pending != null) {
      return pending.future;
    }

    final conversation = conversationsById[id];
    if (conversation == null) {
      throw StateError('Conversation introuvable: $id');
    }
    return conversation;
  }
}

ConversationDto _conversation(
  String id, {
  String? lastMessage,
}) {
  return ConversationDto(
    id: id,
    linkId: 'link-$id',
    ownerId: 'owner',
    anonymousId: 'anon',
    status: 'active',
    createdAt: DateTime(
        2024,
        1,
        int.parse(id.replaceAll(RegExp(r'[^0-9]'), '').isEmpty
            ? '1'
            : id.replaceAll(RegExp(r'[^0-9]'), ''))),
    lastMessage: lastMessage,
    lastMessageAt: DateTime(2024, 2, 1),
  );
}

void main() {
  group('ConversationNotifier', () {
    test(
        'fetchAllSilently keeps loaded extra pages without rewinding nextOffset',
        () async {
      final repo = _FakeConversationRepository()
        ..pagesByOffset[0] = ConversationPageDto(
          items: [_conversation('c1'), _conversation('c2')],
          hasMore: true,
          nextOffset: 2,
        )
        ..pagesByOffset[2] = ConversationPageDto(
          items: [_conversation('c3')],
          hasMore: false,
          nextOffset: null,
        );
      final notifier = ConversationNotifier(repo);

      await notifier.fetchAll();
      await notifier.fetchMore();

      repo.pagesByOffset[0] = ConversationPageDto(
        items: [_conversation('c1', lastMessage: 'new'), _conversation('c2')],
        hasMore: true,
        nextOffset: 2,
      );

      await notifier.fetchAllSilently();

      expect(notifier.state.conversations.map((c) => c.id).toList(),
          ['c1', 'c2', 'c3']);
      expect(notifier.state.nextOffset, 3);
      expect(notifier.state.hasMore, isTrue);
    });

    test('fetchAllSilently drops stale later pages when the API has no more',
        () async {
      final repo = _FakeConversationRepository()
        ..pagesByOffset[0] = ConversationPageDto(
          items: [_conversation('c1'), _conversation('c2')],
          hasMore: true,
          nextOffset: 2,
        )
        ..pagesByOffset[2] = ConversationPageDto(
          items: [_conversation('c3')],
          hasMore: false,
          nextOffset: null,
        );
      final notifier = ConversationNotifier(repo);

      await notifier.fetchAll();
      await notifier.fetchMore();

      repo.pagesByOffset[0] = ConversationPageDto(
        items: [_conversation('c1', lastMessage: 'fresh only')],
        hasMore: false,
        nextOffset: null,
      );

      await notifier.fetchAllSilently();

      expect(
        notifier.state.conversations.map((c) => c.id).toList(),
        ['c1'],
      );
      expect(notifier.state.hasMore, isFalse);
      expect(notifier.state.nextOffset, isNull);
    });

    test(
        'fetchAllSilently drops loaded extra pages when the first page shape changes',
        () async {
      final repo = _FakeConversationRepository()
        ..pagesByOffset[0] = ConversationPageDto(
          items: [_conversation('c1'), _conversation('c2')],
          hasMore: true,
          nextOffset: 2,
        )
        ..pagesByOffset[2] = ConversationPageDto(
          items: [_conversation('c3')],
          hasMore: false,
          nextOffset: null,
        );
      final notifier = ConversationNotifier(repo);

      await notifier.fetchAll();
      await notifier.fetchMore();

      repo.pagesByOffset[0] = ConversationPageDto(
        items: [_conversation('c9'), _conversation('c1')],
        hasMore: true,
        nextOffset: 2,
      );

      await notifier.fetchAllSilently();

      expect(
        notifier.state.conversations.map((c) => c.id).toList(),
        ['c9', 'c1'],
      );
      expect(notifier.state.hasMore, isTrue);
      expect(notifier.state.nextOffset, 2);
    });

    test('refreshOne coalesces concurrent requests for the same conversation',
        () async {
      final repo = _FakeConversationRepository();
      final notifier = ConversationNotifier(repo);
      final completer = Completer<ConversationDto>();

      repo.pendingConversationById['c1'] = completer;

      final first = notifier.refreshOne('c1');
      final second = notifier.refreshOne('c1');

      expect(repo.getConversationCalls['c1'], 1);

      completer.complete(_conversation('c1', lastMessage: 'hello'));
      await Future.wait([first, second]);

      expect(repo.getConversationCalls['c1'], 1);
      expect(notifier.state.conversations.single.id, 'c1');
      expect(notifier.state.conversations.single.lastMessage, 'hello');
    });

    test('fetches are skipped while authenticated session is unavailable',
        () async {
      final repo = _FakeConversationRepository()
        ..allowAuthenticatedSession = false;
      final notifier = ConversationNotifier(repo);

      await notifier.fetchAll();
      await notifier.fetchAllSilently();
      await notifier.fetchMore();
      await notifier.refreshOne('c1');

      expect(repo.getMyConversationsCalls, 0);
      expect(repo.getConversationCalls, isEmpty);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.isLoadingMore, isFalse);
      expect(notifier.state.error, isNull);
    });
  });
}
