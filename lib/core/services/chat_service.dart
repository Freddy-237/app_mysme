import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mysme/core/providers/providers.dart';

void _chatServiceLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

/// Business-layer chat service.
///
/// Primary transport: **Socket.IO**.
/// - Text messages are sent via HTTP REST (server then broadcasts via socket).
/// - Media (image, audio, video, file) is sent as raw bytes over the socket;
///   the server uploads to Cloudinary and broadcasts the [new_message] event.
///
/// Falls back to an [Exception] when the socket is not connected.
class ChatService {
  ChatService(this._ref);

  final Ref _ref;

  SocketService get _socket => _ref.read(socketServiceProvider);
  MessageRepository get _messages => _ref.read(messageRepositoryProvider);

  // ── Text ──────────────────────────────────────────────────────────────────

  /// Send a text message via HTTP (then received by all clients as a socket event).
  Future<MessageDto> sendText(
    String conversationId,
    String content, {
    String? replyToId,
  }) =>
      _messages.sendMessage(
        conversationId,
        content,
        replyToMessageId: replyToId,
      );

  // ── Media (socket) ────────────────────────────────────────────────────────

  /// Send raw [bytes] over Socket.IO.
  ///
  /// The server uploads to Cloudinary, creates the message in the DB and
  /// broadcasts [new_message] to the conversation room.
  ///
  /// Throws [Exception] on socket error or server rejection.
  Future<MessageDto?> sendMediaBytes({
    required String conversationId,
    required Uint8List bytes,
    required String mediaType,
    required String filename,
    String caption = '',
  }) async {
    // Auto-reconnect if the socket dropped (Railway cold-start, network switch…)
    if (!_socket.isConnected) {
      _chatServiceLog(
          '[ChatService] socket disconnected — attempting reconnect');
      await _socket.reconnectIfNeeded();
      if (!_socket.isConnected) {
        throw Exception('Socket déconnecté — impossible d\'envoyer le média');
      }
    }
    final result = await _socket.sendMediaBytes(
      conversationId: conversationId,
      bytes: bytes,
      mediaType: mediaType,
      filename: filename,
      caption: caption,
    );
    if (result == null || result['ok'] != true) {
      final err = (result?['error'] as String?) ?? 'Erreur envoi media';
      _chatServiceLog('[ChatService] sendMediaBytes failed: $err');
      throw Exception(err);
    }
    final msgData = result['message'] as Map<String, dynamic>?;
    if (msgData == null) return null;
    return MessageDto.fromJson(msgData);
  }

  /// Read the file at [filePath] and send its bytes via socket.
  ///
  /// Throws [Exception] when the file does not exist, the socket is
  /// disconnected, or the server rejects the upload.
  Future<MessageDto?> sendMediaFile({
    required String conversationId,
    required String filePath,
    required String mediaType,
    String caption = '',
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Fichier introuvable: $filePath');
    }
    final bytes = await file.readAsBytes();
    final filename = filePath.split(RegExp(r'[\\/]')).last;
    return sendMediaBytes(
      conversationId: conversationId,
      bytes: bytes,
      mediaType: mediaType,
      filename: filename,
      caption: caption,
    );
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(ref));
