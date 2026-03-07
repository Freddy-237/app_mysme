import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/http_client.dart';

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

  /// 7-day window from started_at.
  DateTime? get expiresAt {
    if (startedAt == null) return null;
    return startedAt!.add(const Duration(days: 7));
  }

  Duration get remainingTime {
    final exp = expiresAt;
    if (exp == null) return Duration.zero;
    final diff = exp.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get isExpired {
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

  /// Start a conversation via invite code.
  Future<ConversationDto> startConversation(String inviteCode) async {
    final json = await _client.post(
      '/conversation/start',
      {'inviteCode': inviteCode},
    );
    return ConversationDto.fromJson(json as Map<String, dynamic>);
  }

  /// Get my conversations.
  Future<List<ConversationDto>> getMyConversations() async {
    final json = await _client.get('/conversation/mine');
    debugPrint(
        '[ConvRepo.getMyConversations] raw response type=${json.runtimeType} length=${(json as List).length}');
    if ((json).isNotEmpty) {
      debugPrint('[ConvRepo.getMyConversations] first item: ${json[0]}');
    }
    return json
        .map((e) => ConversationDto.fromJson(e as Map<String, dynamic>))
        .toList();
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
    this.error,
  });

  final List<ConversationDto> conversations;
  final bool isLoading;
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
    String? error,
  }) {
    return ConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

class ConversationNotifier extends StateNotifier<ConversationsState> {
  ConversationNotifier(this._repo) : super(const ConversationsState());

  final ConversationRepository _repo;

  /// Fetch all my conversations.
  Future<void> fetchAll() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repo.getMyConversations();
      debugPrint('[ConvNotifier.fetchAll] got ${list.length} conversations');
      for (final c in list) {
        debugPrint(
            '[ConvNotifier.fetchAll]   conv id=${c.id} owner=${c.ownerId} anon=${c.anonymousId} status=${c.status}');
      }
      state = ConversationsState(conversations: list);
    } catch (e) {
      debugPrint('[ConvNotifier.fetchAll] ERROR: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Refresh all conversations without toggling loading state.
  Future<void> fetchAllSilently() async {
    try {
      final list = await _repo.getMyConversations();
      debugPrint(
          '[ConvNotifier.fetchAllSilently] got ${list.length} conversations');
      state = state.copyWith(conversations: list, error: null);
    } catch (e) {
      debugPrint('[ConvNotifier.fetchAllSilently] ERROR: $e');
    }
  }

  /// Start a new conversation with an invite code.
  Future<ConversationDto> startConversation(String inviteCode) async {
    final conv = await _repo.startConversation(inviteCode);
    state = ConversationsState(
      conversations: [conv, ...state.conversations],
    );
    return conv;
  }

  /// Block a conversation.
  Future<void> blockConversation(String id) async {
    try {
      final updated = await _repo.blockConversation(id);
      state = ConversationsState(
        conversations:
            state.conversations.map((c) => c.id == id ? updated : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Archive a conversation.
  Future<void> archiveConversation(String id) async {
    try {
      final updated = await _repo.archiveConversation(id);
      state = ConversationsState(
        conversations:
            state.conversations.map((c) => c.id == id ? updated : c).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Delete (soft-delete) a conversation — removes from list locally.
  Future<void> deleteConversation(String id) async {
    try {
      await _repo.deleteConversation(id);
      state = ConversationsState(
        conversations: state.conversations.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Mark all messages in a conversation as read, clear unread badge.
  Future<void> markAsRead(String id) async {
    try {
      await _repo.markAsRead(id);
      state = ConversationsState(
        conversations: state.conversations
            .map((c) => c.id == id ? c.withUnread(0) : c)
            .toList(),
      );
    } catch (_) {}
  }

  /// Increment unread for a conversation (called on socket new_message).
  void incrementUnread(String id) {
    state = ConversationsState(
      conversations: state.conversations
          .map((c) => c.id == id ? c.withUnread(c.unreadCount + 1) : c)
          .toList(),
    );
  }

  /// Update last message preview (called on socket new_message).
  void updateLastMessage(String id, String content, String senderId) {
    state = ConversationsState(
      conversations: state.conversations
          .map((c) => c.id == id ? c.withLastMessage(content, senderId) : c)
          .toList(),
    );
  }

  /// Refresh a single conversation.
  Future<void> refreshOne(String id) async {
    try {
      final conv = await _repo.getConversation(id);
      final exists = state.conversations.any((c) => c.id == id);
      state = ConversationsState(
        conversations: exists
            ? state.conversations.map((c) => c.id == id ? conv : c).toList()
            : [conv, ...state.conversations],
      );
    } catch (_) {}
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
