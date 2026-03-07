import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:mysme/core/providers/http_client.dart';

// ---------------------------------------------------------------------------
// Message DTO (mirrors backend row)
// ---------------------------------------------------------------------------

class MessageDto {
  const MessageDto({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.isDeleted,
    required this.createdAt,
    this.isRead = false,
    this.mediaUrl,
    this.mediaType,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderId,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final bool isDeleted;
  final DateTime createdAt;
  final bool isRead;
  final String? mediaUrl;
  final String? mediaType;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderId;

  bool get isVideo => mediaType == 'video' && mediaUrl != null;

  /// Whether this message was sent by [currentUserId].
  bool isSelf(String currentUserId) => senderId == currentUserId;

  /// Formatted time HH:mm.
  String get formattedTime => '${createdAt.hour.toString().padLeft(2, '0')}:'
      '${createdAt.minute.toString().padLeft(2, '0')}';

  factory MessageDto.fromJson(Map<String, dynamic> json) {
    return MessageDto(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      content: json['content'] as String? ?? '',
      isDeleted: json['is_deleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
      mediaUrl: json['media_url'] as String?,
      mediaType: json['media_type'] as String?,
      replyToMessageId: json['reply_to_message_id'] as String?,
      replyToContent: json['reply_to_content'] as String?,
      replyToSenderId: json['reply_to_sender_id'] as String?,
    );
  }

  MessageDto copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    bool? isDeleted,
    DateTime? createdAt,
    bool? isRead,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
    String? replyToContent,
    String? replyToSenderId,
  }) {
    return MessageDto(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      replyToMessageId: replyToMessageId ?? this.replyToMessageId,
      replyToContent: replyToContent ?? this.replyToContent,
      replyToSenderId: replyToSenderId ?? this.replyToSenderId,
    );
  }
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------

class MessageRepository {
  MessageRepository(this._client);
  final HttpClient _client;

  /// Send a message.
  Future<MessageDto> sendMessage(
    String conversationId,
    String content, {
    String? replyToMessageId,
  }) async {
    final payload = <String, dynamic>{
      'conversationId': conversationId,
      'content': content,
    };
    if (replyToMessageId != null) {
      payload['replyToMessageId'] = replyToMessageId;
    }

    final json = await _client.post('/message', payload);
    return MessageDto.fromJson(json as Map<String, dynamic>);
  }

  /// Upload and send a media message (video, image, file, or audio).
  Future<MessageDto> _sendMedia(
    String conversationId,
    String filePath,
    String fieldName,
    String endpoint, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final fileName = filePath.split(RegExp(r'[\\/]')).last;
    final file = File(filePath);
    final exists = await file.exists();
    final fileSize = exists ? await file.length() : -1;
    debugPrint(
      '[MessageRepo._sendMedia] start endpoint=$endpoint field=$fieldName '
      'conversationId=$conversationId fileName=$fileName exists=$exists '
      'size=$fileSize path=$filePath',
    );
    final formData = FormData.fromMap({
      'conversationId': conversationId,
      fieldName: await MultipartFile.fromFile(filePath, filename: fileName),
    });

    try {
      final res = await _client.dio.post(
        endpoint,
        data: formData,
        options: Options(receiveTimeout: const Duration(seconds: 120)),
        onSendProgress: (sent, total) {
          debugPrint(
            '[MessageRepo._sendMedia] progress endpoint=$endpoint '
            'sent=$sent total=$total',
          );
          onProgress?.call(sent, total);
        },
      );
      debugPrint(
        '[MessageRepo._sendMedia] success endpoint=$endpoint '
        'status=${res.statusCode} data=${res.data}',
      );
      return MessageDto.fromJson(res.data as Map<String, dynamic>);
    } catch (e, st) {
      debugPrint('[MessageRepo._sendMedia] ERROR endpoint=$endpoint error=$e');
      debugPrint('$st');
      rethrow;
    }
  }

  /// Upload and send a video message.
  Future<MessageDto> sendVideo(
    String conversationId,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) =>
      _sendMedia(conversationId, filePath, 'video', '/message/video',
          onProgress: onProgress);

  /// Upload and send an image message.
  Future<MessageDto> sendImage(
    String conversationId,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) =>
      _sendMedia(conversationId, filePath, 'image', '/message/image',
          onProgress: onProgress);

  /// Upload and send a generic file message.
  Future<MessageDto> sendFile(
    String conversationId,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) =>
      _sendMedia(conversationId, filePath, 'file', '/message/file',
          onProgress: onProgress);

  /// Upload and send an audio message.
  Future<MessageDto> sendAudio(
    String conversationId,
    String filePath, {
    void Function(int sent, int total)? onProgress,
  }) =>
      _sendMedia(conversationId, filePath, 'audio', '/message/audio',
          onProgress: onProgress);

  /// Get messages for a conversation with pagination.
  Future<List<MessageDto>> getMessages(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final json = await _client.get(
      '/message/$conversationId',
      query: {'limit': '$limit', 'offset': '$offset'},
    );
    return (json as List)
        .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Soft-delete a message.
  Future<MessageDto> deleteMessage(String messageId) async {
    final json = await _client.delete('/message/$messageId');
    return MessageDto.fromJson(json as Map<String, dynamic>);
  }

  /// Hide a message only for current user.
  Future<void> hideMessageForMe(String messageId) async {
    await _client.post('/message/$messageId/hide', {});
  }

  /// Unhide a previously hidden message for current user.
  Future<void> unhideMessageForMe(String messageId) async {
    await _client.post('/message/$messageId/unhide', {});
  }

  /// Search messages in a conversation.
  Future<List<MessageDto>> searchMessages(
    String conversationId,
    String query, {
    int limit = 30,
    int offset = 0,
  }) async {
    final json = await _client.get(
      '/message/$conversationId/search',
      query: {'q': query, 'limit': '$limit', 'offset': '$offset'},
    );
    return (json as List)
        .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Get media messages for a conversation.
  Future<List<MessageDto>> getMedia(
    String conversationId, {
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    final q = <String, String>{
      'limit': '$limit',
      'offset': '$offset',
    };
    if (type != null) q['type'] = type;
    final json = await _client.get(
      '/message/$conversationId/media',
      query: q,
    );
    return (json as List)
        .map((e) => MessageDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

// ---------------------------------------------------------------------------
// State (per conversation)
// ---------------------------------------------------------------------------

class MessagesState {
  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.error,
  });

  final List<MessageDto> messages;
  final bool isLoading;
  final bool isSending;
  final String? error;

  MessagesState copyWith({
    List<MessageDto>? messages,
    bool? isLoading,
    bool? isSending,
    String? error,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      error: error,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier — scoped to one conversation
// ---------------------------------------------------------------------------

class MessageNotifier extends StateNotifier<MessagesState> {
  MessageNotifier(this._repo, this._conversationId)
      : super(const MessagesState());

  final MessageRepository _repo;
  final String _conversationId;

  /// Load messages for this conversation.
  Future<void> fetchMessages({int limit = 50, int offset = 0}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final msgs = await _repo.getMessages(
        _conversationId,
        limit: limit,
        offset: offset,
      );
      state = MessagesState(messages: msgs);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Poll for new messages (smart merge — only update if changed).
  Future<void> poll() async {
    try {
      final msgs = await _repo.getMessages(_conversationId);
      if (msgs.length != state.messages.length ||
          (msgs.isNotEmpty && msgs.last.id != state.messages.lastOrNull?.id)) {
        state = state.copyWith(messages: msgs);
      }
    } catch (_) {}
  }

  /// Send a message.
  Future<void> sendMessage(String content) async {
    state = state.copyWith(isSending: true, error: null);
    try {
      final msg = await _repo.sendMessage(_conversationId, content);
      state = MessagesState(
        messages: [...state.messages, msg],
      );
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  /// Delete a message.
  Future<void> deleteMessage(String messageId) async {
    try {
      await _repo.deleteMessage(messageId);
      state = MessagesState(
        messages: state.messages.where((m) => m.id != messageId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Add a message received via socket (avoid duplicates).
  void addSocketMessage(MessageDto msg) {
    if (msg.conversationId != _conversationId) return;
    if (state.messages.any((m) => m.id == msg.id)) return;
    state = state.copyWith(messages: [...state.messages, msg]);
  }

  /// Remove a message deleted by socket event.
  void removeMessage(String messageId) {
    state = state.copyWith(
      messages: state.messages.where((m) => m.id != messageId).toList(),
    );
  }

  /// Mark all messages as read locally.
  void markAllRead() {
    state = state.copyWith(
      messages: state.messages.map((m) => m.copyWith(isRead: true)).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.watch(httpClientProvider));
});

/// Family provider — one notifier per conversation.
final messageProvider =
    StateNotifierProvider.family<MessageNotifier, MessagesState, String>(
        (ref, conversationId) {
  return MessageNotifier(
    ref.watch(messageRepositoryProvider),
    conversationId,
  );
});
