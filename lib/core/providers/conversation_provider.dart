import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mysme/core/config/monetization.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/utils/helpers.dart';

// Intentionally ignore futures where we don't want to await the result.
void _ignoreFuture(Future<void> f) {}

void _convLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

const _conversationPageSize = 30;
const _unsetPaginationOffset = Object();
const _conversationsCacheKey = 'mystme_conversations_cache_v1';

class ConversationPageDto {
  const ConversationPageDto({
    required this.items,
    required this.hasMore,
    required this.nextOffset,
  });

  final List<ConversationDto> items;
  final bool hasMore;
  final int? nextOffset;
}

// ---------------------------------------------------------------------------
// Conversation model (mirrors backend row)
// ---------------------------------------------------------------------------

class ConversationDto {
  const ConversationDto({
    required this.id,
    required this.linkId,
    required this.ownerId,
    this.anonymousId,
    required this.status,
    this.startedAt,
    this.expiresAt,
    this.blockedAt,
    required this.createdAt,
    this.unreadCount = 0,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageAt,
    this.ownerPseudo,
    this.anonymousPseudo,
  });

  final String id;
  final String linkId;
  final String ownerId;
  final String? anonymousId;
  final String status; // 'active' | 'blocked' | 'expired' | 'archived'
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime? blockedAt;
  final DateTime createdAt;
  final int unreadCount;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final DateTime? lastMessageAt;
  final String? ownerPseudo;
  final String? anonymousPseudo;

  bool get isActive => status == 'active';
  bool get isBlocked => status == 'blocked';
  bool get isArchived => status == 'archived';
  bool get hasUnread => unreadCount > 0;

  /// Get the pseudo of the other participant.
  String peerPseudo(String myId) {
    if (myId == ownerId) {
      return anonymousPseudo ?? 'Anonyme';
    }
    return ownerPseudo ?? 'Anonyme';
  }

  Duration get remainingTime {
    if (!kConversationExpiryEnabled) {
      return const Duration(days: 36500);
    }
    final exp = expiresAt;
    if (exp == null) return Duration.zero;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired {
    if (!kConversationExpiryEnabled) {
      return false;
    }
    final exp = expiresAt;
    if (exp == null) return false;
    return DateTime.now().isAfter(exp);
  }

  factory ConversationDto.fromJson(Map<String, dynamic> json) {
    return ConversationDto(
      id: json['id'] as String,
      linkId: json['link_id'] as String,
      ownerId: json['owner_id'] as String,
      anonymousId: json['anonymous_id'] as String?,
      status: json['status'] as String? ?? 'active',
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      blockedAt: json['blocked_at'] != null
          ? DateTime.parse(json['blocked_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      unreadCount: int.tryParse('${json['unread_count'] ?? 0}') ?? 0,
      lastMessage: json['last_message'] as String?,
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      ownerPseudo: json['owner_pseudo'] as String?,
      anonymousPseudo: json['anonymous_pseudo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'link_id': linkId,
      'owner_id': ownerId,
      'anonymous_id': anonymousId,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'blocked_at': blockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'unread_count': unreadCount,
      'last_message': lastMessage,
      'last_message_sender_id': lastMessageSenderId,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'owner_pseudo': ownerPseudo,
      'anonymous_pseudo': anonymousPseudo,
    };
  }

  /// Return a copy with updated unread count (used after socket events).
  ConversationDto withUnread(int count) => copyWith(unreadCount: count);

  /// Return a copy with a new last message (used after socket new_message).
  ConversationDto withLastMessage(String content, String senderId) => copyWith(
        lastMessage: content,
        lastMessageSenderId: senderId,
        lastMessageAt: DateTime.now(),
      );

  ConversationDto copyWith({
    String? id,
    String? linkId,
    String? ownerId,
    String? anonymousId,
    String? status,
    DateTime? startedAt,
    DateTime? expiresAt,
    DateTime? blockedAt,
    DateTime? createdAt,
    int? unreadCount,
    String? lastMessage,
    String? lastMessageSenderId,
    DateTime? lastMessageAt,
    String? ownerPseudo,
    String? anonymousPseudo,
  }) {
    return ConversationDto(
      id: id ?? this.id,
      linkId: linkId ?? this.linkId,
      ownerId: ownerId ?? this.ownerId,
      anonymousId: anonymousId ?? this.anonymousId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      blockedAt: blockedAt ?? this.blockedAt,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      ownerPseudo: ownerPseudo ?? this.ownerPseudo,
      anonymousPseudo: anonymousPseudo ?? this.anonymousPseudo,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class ConversationRepository {
  ConversationRepository(this._client);
  final HttpClient _client;

  bool get hasAuthenticatedSession => _client.isReady;

  /// Start a conversation via invite code.
  Future<ConversationDto> startConversation(String inviteCode) async {
    final json = await _client.post(
      '/conversation/resolve-link',
      {'inviteCode': inviteCode},
    );
    return ConversationDto.fromJson(
      (json as Map<String, dynamic>)['conversation'] as Map<String, dynamic>,
    );
  }

  /// Get my conversations.
  Future<ConversationPageDto> getMyConversations({
    int limit = _conversationPageSize,
    int offset = 0,
  }) async {
    final raw = await _client.get(
      '/conversation/mine',
      query: {
        'limit': '$limit',
        'offset': '$offset',
      },
    );
    if (raw is List) {
      final items = raw
          .map((e) =>
              ConversationDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ConversationPageDto(
        items: items,
        hasMore: items.length == limit,
        nextOffset: items.length == limit ? offset + items.length : null,
      );
    }

    if (raw is! Map) {
      throw const FormatException('Réponse /conversation/mine invalide');
    }

    final body = Map<String, dynamic>.from(raw);
    final itemsRaw = body['items'];
    final pageInfoRaw = body['pageInfo'];
    if (itemsRaw is! List || pageInfoRaw is! Map) {
      throw const FormatException('Pagination /conversation/mine invalide');
    }

    final items = itemsRaw
        .map((e) =>
            ConversationDto.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    final pageInfo = Map<String, dynamic>.from(pageInfoRaw);

    _convLog(
      '[ConvRepo.getMyConversations] offset=$offset limit=$limit count=${items.length} hasMore=${pageInfo['hasMore']}',
    );

    return ConversationPageDto(
      items: items,
      hasMore: pageInfo['hasMore'] == true,
      nextOffset: (pageInfo['nextOffset'] as num?)?.toInt(),
    );
  }

  /// Get a single conversation.
  Future<ConversationDto> getConversation(String id) async {
    final json = await _client.get('/conversation/$id');
    return ConversationDto.fromJson(json as Map<String, dynamic>);
  }

  /// Block a conversation.
  Future<ConversationDto> blockConversation(String id) async {
    final json = await _client.post('/conversation/$id/block', {});
    return ConversationDto.fromJson(json as Map<String, dynamic>);
  }

  /// Archive a conversation (soft hide from list).
  Future<ConversationDto> archiveConversation(String id) async {
    final json = await _client.post('/conversation/$id/archive', {});
    return ConversationDto.fromJson(json as Map<String, dynamic>);
  }

  /// Delete a conversation (moves to archived).
  Future<ConversationDto> deleteConversation(String id) async {
    final json = await _client.delete('/conversation/$id');
    return ConversationDto.fromJson(json as Map<String, dynamic>);
  }

  /// Mark all messages in a conversation as read.
  Future<void> markAsRead(String id) async {
    await _client.post('/conversation/$id/read', {});
  }
}

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ConversationsState {
  const ConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextOffset,
    this.error,
  });

  final List<ConversationDto> conversations;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int? nextOffset;
  final String? error;

  /// Total unread count across all conversations.
  int get totalUnread => conversations.fold(0, (sum, c) => sum + c.unreadCount);

  /// Active conversations sorted by most recent message.
  List<ConversationDto> get active {
    final list =
        conversations.where((c) => c.isActive && !c.isExpired).toList();
    list.sort((a, b) {
      final aTime = a.lastMessageAt ?? a.createdAt;
      final bTime = b.lastMessageAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return list;
  }

  ConversationsState copyWith({
    List<ConversationDto>? conversations,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? nextOffset = _unsetPaginationOffset,
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: identical(nextOffset, _unsetPaginationOffset)
          ? this.nextOffset
          : nextOffset as int?,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ConversationNotifier extends StateNotifier<ConversationsState> {
  ConversationNotifier(this._repo) : super(const ConversationsState()) {
    // Rehydrate cached conversations immediately for faster perceived load.
    _ignoreFuture(_rehydrateCache());
  }

  final ConversationRepository _repo;
  Future<void>? _inFlightSilentRefresh;
  final Map<String, Future<void>> _inFlightSingleRefreshes = {};

  Future<void> _rehydrateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_conversationsCacheKey);
      if (raw == null || raw.isEmpty) return;
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final itemsRaw = decoded['items'] as List<dynamic>?;
      final hasMore = decoded['hasMore'] as bool? ?? true;
      final nextOffset = (decoded['nextOffset'] as num?)?.toInt();
      if (itemsRaw == null) return;
      final items = itemsRaw
          .map((e) =>
              ConversationDto.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      state = state.copyWith(
        conversations: items,
        hasMore: hasMore,
        nextOffset: nextOffset,
        error: null,
      );
      // Refresh silently to get up-to-date data.
      _ignoreFuture(fetchAllSilently());
    } catch (e) {
      _convLog('[ConvNotifier._rehydrateCache] ERROR: $e');
    }
  }

  Future<void> _saveCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Keep a reasonable cap to avoid storing huge payloads.
      final cap = 200;
      final items =
          state.conversations.take(cap).map((c) => c.toJson()).toList();
      final encoded = json.encode({
        'items': items,
        'hasMore': state.hasMore,
        'nextOffset': state.nextOffset,
      });
      await prefs.setString(_conversationsCacheKey, encoded);
    } catch (e) {
      _convLog('[ConvNotifier._saveCache] ERROR: $e');
    }
  }

  bool _skipIfSessionUnavailable({
    required bool resetLoading,
    bool resetLoadingMore = false,
  }) {
    if (_repo.hasAuthenticatedSession) {
      return false;
    }

    _convLog('[ConvNotifier] skip fetch: authenticated session unavailable');
    state = state.copyWith(
      isLoading: resetLoading ? false : null,
      isLoadingMore: resetLoadingMore ? false : null,
      error: null,
    );
    return true;
  }

  String _messageForFetchError(Object error, String fallback) {
    if (error is SessionLostException) {
      return error.message;
    }
    if (error is ApiException) {
      if (error.statusCode == 401) {
        return 'Session indisponible. Recharge ton identite puis reessaie.';
      }
      if (error.statusCode == 429) {
        return 'Trop de requetes. Patiente un instant puis reessaie.';
      }
    }
    return fallback;
  }

  /// Fetch all my conversations.
  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, isLoadingMore: false, error: null);
    if (_skipIfSessionUnavailable(resetLoading: true, resetLoadingMore: true)) {
      return;
    }
    try {
      final list = await _repo.getMyConversations(
        limit: _conversationPageSize,
        offset: 0,
      );
      _convLog(
          '[ConvNotifier.fetchAll] got ${list.items.length} conversations');
      if (list.items.isEmpty) {
        _convLog('[ConvNotifier.fetchAll] empty list returned by API');
      }
      state = ConversationsState(
        conversations: list.items,
        hasMore: list.hasMore,
        nextOffset: list.nextOffset,
      );
      _ignoreFuture(_saveCache());
    } catch (e, st) {
      _convLog('[ConvNotifier.fetchAll] ERROR: $e');
      if (kDebugMode) {
        debugPrintStack(stackTrace: st);
      }
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error:
            _messageForFetchError(e, 'Chargement des discussions impossible'),
      );
    }
  }

  /// Refresh all conversations without toggling loading state.
  Future<void> fetchAllSilently() async {
    final inFlight = _inFlightSilentRefresh;
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final request = _fetchAllSilentlyInternal();
    _inFlightSilentRefresh = request;
    try {
      await request;
    } finally {
      if (identical(_inFlightSilentRefresh, request)) {
        _inFlightSilentRefresh = null;
      }
    }
  }

  Future<void> _fetchAllSilentlyInternal() async {
    if (_skipIfSessionUnavailable(resetLoading: false)) {
      return;
    }
    try {
      final list = await _repo.getMyConversations(
        limit: _conversationPageSize,
        offset: 0,
      );
      _convLog(
          '[ConvNotifier.fetchAllSilently] got ${list.items.length} conversations');
      final previousFirstPageIds = state.conversations
          .take(list.items.length)
          .map((conversation) => conversation.id)
          .toList();
      final firstPageIds = list.items.map((c) => c.id).toSet();
      final firstPageShapeChanged = !listEquals(
          previousFirstPageIds, list.items.map((c) => c.id).toList());
      final shouldPreserveLoadedPages = list.hasMore &&
          !firstPageShapeChanged &&
          state.conversations.length > list.items.length;
      final remaining = shouldPreserveLoadedPages
          ? state.conversations
              .where((conversation) => !firstPageIds.contains(conversation.id))
              .toList()
          : const <ConversationDto>[];
      final merged = [...list.items, ...remaining];
      final nextOffset = list.hasMore
          ? shouldPreserveLoadedPages
              ? math.max(list.nextOffset ?? list.items.length, merged.length)
              : list.nextOffset
          : list.nextOffset;
      state = state.copyWith(
        conversations: merged,
        hasMore: list.hasMore,
        nextOffset: nextOffset,
        error: null,
      );
      _ignoreFuture(_saveCache());
    } catch (e) {
      _convLog('[ConvNotifier.fetchAllSilently] ERROR: $e');
      state = state.copyWith(
        error: _messageForFetchError(
            e, 'Actualisation des discussions impossible'),
      );
    }
  }

  Future<void> fetchMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, error: null);
    if (_skipIfSessionUnavailable(
        resetLoading: false, resetLoadingMore: true)) {
      return;
    }
    try {
      final nextPage = await _repo.getMyConversations(
        limit: _conversationPageSize,
        offset: state.nextOffset ?? state.conversations.length,
      );
      final existingIds = state.conversations.map((c) => c.id).toSet();
      final appended = nextPage.items
          .where((conversation) => !existingIds.contains(conversation.id))
          .toList();

      state = state.copyWith(
        conversations: [...state.conversations, ...appended],
        isLoadingMore: false,
        hasMore: nextPage.hasMore,
        nextOffset: nextPage.nextOffset,
        error: null,
      );
      _ignoreFuture(_saveCache());
    } catch (e) {
      _convLog('[ConvNotifier.fetchMore] ERROR: $e');
      state = state.copyWith(
        isLoadingMore: false,
        error: _messageForFetchError(
          e,
          'Chargement de plus de discussions impossible',
        ),
      );
    }
  }

  /// Start a new conversation with an invite code.
  Future<ConversationDto> startConversation(String inviteCode) async {
    final conv = await _repo.startConversation(inviteCode);
    state = state.copyWith(
      conversations: [conv, ...state.conversations],
    );
    _ignoreFuture(_saveCache());
    return conv;
  }

  /// Block a conversation.
  Future<void> blockConversation(String id) async {
    try {
      final updated = await _repo.blockConversation(id);
      state = state.copyWith(
        conversations:
            state.conversations.map((c) => c.id == id ? updated : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de bloquer cette discussion pour le moment.',
        ),
      );
    }
  }

  /// Archive a conversation.
  Future<void> archiveConversation(String id) async {
    try {
      final updated = await _repo.archiveConversation(id);
      state = state.copyWith(
        conversations:
            state.conversations.map((c) => c.id == id ? updated : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible d\'archiver cette discussion pour le moment.',
        ),
      );
    }
  }

  /// Delete (soft-delete) a conversation — removes from list locally.
  Future<void> deleteConversation(String id) async {
    try {
      await _repo.deleteConversation(id);
      state = state.copyWith(
        conversations: state.conversations.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        error: Helpers.friendlyErrorMessage(
          e,
          fallback: 'Impossible de supprimer cette discussion pour le moment.',
        ),
      );
    }
  }

  /// Mark all messages in a conversation as read, clear unread badge.
  Future<void> markAsRead(String id) async {
    try {
      await _repo.markAsRead(id);
      state = state.copyWith(
        conversations: state.conversations
            .map((c) => c.id == id ? c.withUnread(0) : c)
            .toList(),
      );
    } catch (e) {
      _convLog('[ConvNotifier.markAsRead] ERROR: $e');
      state = state.copyWith(
          error: 'Impossible de marquer la conversation comme lue');
    }
  }

  /// Increment unread for a conversation (called on socket new_message).
  void incrementUnread(String id) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == id ? c.withUnread(c.unreadCount + 1) : c)
          .toList(),
    );
  }

  /// Clear unread locally before server confirmation when the chat is open.
  void clearUnread(String id) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == id ? c.withUnread(0) : c)
          .toList(),
    );
  }

  /// Update last message preview (called on socket new_message).
  void updateLastMessage(String id, String content, String senderId) {
    state = state.copyWith(
      conversations: state.conversations
          .map((c) => c.id == id ? c.withLastMessage(content, senderId) : c)
          .toList(),
    );
  }

  /// Refresh a single conversation.
  Future<void> refreshOne(String id) async {
    final inFlight = _inFlightSingleRefreshes[id];
    if (inFlight != null) {
      await inFlight;
      return;
    }

    final request = _refreshOneInternal(id);
    _inFlightSingleRefreshes[id] = request;
    try {
      await request;
    } finally {
      if (identical(_inFlightSingleRefreshes[id], request)) {
        _inFlightSingleRefreshes.remove(id);
      }
    }
  }

  Future<void> _refreshOneInternal(String id) async {
    if (_skipIfSessionUnavailable(resetLoading: false)) {
      return;
    }
    try {
      final conv = await _repo.getConversation(id);
      final exists = state.conversations.any((c) => c.id == id);
      state = state.copyWith(
        conversations: exists
            ? state.conversations.map((c) => c.id == id ? conv : c).toList()
            : [conv, ...state.conversations],
      );
    } catch (e) {
      _convLog('[ConvNotifier.refreshOne] ERROR id=$id: $e');
    }
  }

  Future<void> refreshMany(Iterable<String> ids) async {
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    if (uniqueIds.isEmpty) return;
    if (_skipIfSessionUnavailable(resetLoading: false)) {
      return;
    }

    try {
      final conversations = await Future.wait(
        uniqueIds.map(_repo.getConversation),
      );
      final replacements = {
        for (final conversation in conversations) conversation.id: conversation,
      };
      state = state.copyWith(
        conversations: state.conversations
            .map(
                (conversation) => replacements[conversation.id] ?? conversation)
            .toList(),
        error: null,
      );
    } catch (e) {
      _convLog('[ConvNotifier.refreshMany] ERROR: $e');
      state = state.copyWith(error: 'Actualisation ciblée impossible');
    }
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final conversationRepositoryProvider = Provider<ConversationRepository>((ref) {
  return ConversationRepository(ref.watch(httpClientProvider));
});

final conversationProvider =
    StateNotifierProvider<ConversationNotifier, ConversationsState>((ref) {
  return ConversationNotifier(ref.watch(conversationRepositoryProvider));
});

/// Provider for a single conversation by ID.
final singleConversationProvider =
    FutureProvider.family<ConversationDto, String>((ref, id) async {
  final repo = ref.watch(conversationRepositoryProvider);
  return repo.getConversation(id);
});
