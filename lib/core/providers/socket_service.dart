import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;
import 'package:mysme/core/services/offline_queue_service.dart';

void _socketLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

// ---------------------------------------------------------------------------
// Event name constants
// ---------------------------------------------------------------------------

abstract class SocketEvents {
  static const newMessage = 'new_message';
  static const messageDeleted = 'message_deleted';
  static const typingStart = 'typing_start';
  static const typingStop = 'typing_stop';
  static const messagesRead = 'messages_read';
  static const newConversation = 'new_conversation';
  static const userOnline = 'user_online';
  static const userOffline = 'user_offline';
  static const checkPresence = 'check_presence';
  static const presenceResult = 'presence_result';
  static const sendMedia = 'send_media';
  static const mediaError = 'media_error';
}

// ---------------------------------------------------------------------------
// SocketService — thin wrapper around socket_io_client
// ---------------------------------------------------------------------------

typedef JsonCallback = void Function(Map<String, dynamic> data);
typedef StringCallback = void Function(String conversationId);
typedef DisposeCallback = void Function();

const _kSocketConnectTimeout = Duration(seconds: 12);

class SocketService {
  SocketService(this._storage, {this.offlineQueue});
  final FlutterSecureStorage _storage;

  /// Optional offline queue — flushed automatically on reconnect.
  final OfflineQueueService? offlineQueue;

  sio.Socket? _socket;
  bool get isConnected => _socket?.connected ?? false;

  /// Track joined rooms so we can re-join after reconnect.
  final Set<String> _joinedRooms = {};
  Completer<void>? _inFlightConnect;

  // ── life-cycle ────────────────────────────────────────────────────────────

  String? _serverUrl;

  Future<void> connect(String serverUrl) async {
    _serverUrl = serverUrl;

    // If already connected, nothing to do.
    if (isConnected) return;

    final existingConnect = _inFlightConnect;
    if (existingConnect != null) {
      await existingConnect.future;
      return;
    }

    final completer = Completer<void>();
    _inFlightConnect = completer;

    // Dispose previous dead socket before creating a new one.
    _socket?.dispose();
    _socket = null;

    final token = await _storage.read(key: 'mystme_token');

    final socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token ?? ''})
          .enableReconnection()
          .setReconnectionAttempts(double.maxFinite.toInt())
          .setReconnectionDelay(2000)
          .setReconnectionDelayMax(30000)
          .build(),
    );
    _socket = socket;

    // Re-join all tracked rooms after reconnect & flush offline queue
    socket.onConnect((_) {
      _socketLog('[SocketService] connected');
      for (final roomId in _joinedRooms) {
        socket.emit('join_conversation', roomId);
      }
      unawaited(offlineQueue?.pruneAndFlush() ?? Future<int>.value(0));
      if (identical(_socket, socket) && !completer.isCompleted) {
        completer.complete();
      }
    });

    socket.onDisconnect((reason) {
      _socketLog('[SocketService] disconnected reason=$reason');
      if (identical(_socket, socket) && !completer.isCompleted) {
        completer.completeError(
          Exception('Socket déconnecté avant établissement de la connexion'),
        );
      }
    });

    socket.onConnectError((data) {
      _socketLog('[SocketService] connect error: $data');
      if (identical(_socket, socket) && !completer.isCompleted) {
        completer.completeError(
          Exception('Connexion socket impossible: $data'),
        );
      }
    });

    socket.onError((data) {
      _socketLog('[SocketService] socket error: $data');
      if (identical(_socket, socket) && !completer.isCompleted) {
        completer.completeError(Exception('Erreur socket: $data'));
      }
    });

    socket.connect();

    try {
      await completer.future.timeout(_kSocketConnectTimeout);
    } catch (_) {
      if (identical(_socket, socket)) {
        socket.disconnect();
        _socket = null;
      }
      rethrow;
    } finally {
      if (identical(_inFlightConnect, completer)) {
        _inFlightConnect = null;
      }
    }
  }

  /// Reconnect with a fresh token (e.g. after app resume).
  Future<void> reconnectIfNeeded() async {
    if (_serverUrl == null) return;
    if (isConnected) return;
    await connect(_serverUrl!);
  }

  void disconnect() {
    _inFlightConnect = null;
    _joinedRooms.clear();
    _socket?.disconnect();
    _socket = null;
  }

  // ── rooms ─────────────────────────────────────────────────────────────────

  void joinConversation(String conversationId) {
    _joinedRooms.add(conversationId);
    _socket?.emit('join_conversation', conversationId);
  }

  void leaveConversation(String conversationId) {
    _joinedRooms.remove(conversationId);
    _socket?.emit('leave_conversation', conversationId);
  }

  // ── typing ────────────────────────────────────────────────────────────────

  void emitTypingStart(String conversationId) {
    _socket?.emit(SocketEvents.typingStart, {'conversationId': conversationId});
  }

  void emitTypingStop(String conversationId) {
    _socket?.emit(SocketEvents.typingStop, {'conversationId': conversationId});
  }

  // ── read receipts ─────────────────────────────────────────────────────────

  void emitMarkRead(String conversationId) {
    _socket
        ?.emit(SocketEvents.messagesRead, {'conversationId': conversationId});
  }
  // ── media upload (socket) ────────────────────────────────────────────

  /// Send [bytes] to the server via Socket.IO `send_media` event and wait
  /// for the acknowledgement that includes the created message or an error.
  ///
  /// Returns the raw ack payload, or null on timeout / disconnected.
  Future<Map<String, dynamic>?> sendMediaBytes({
    required String conversationId,
    required Uint8List bytes,
    required String mediaType,
    required String filename,
    String caption = '',
  }) {
    if (_socket == null || !isConnected) return Future.value(null);

    final completer = Completer<Map<String, dynamic>?>();

    _socket!.emitWithAck(
      SocketEvents.sendMedia,
      {
        'conversationId': conversationId,
        'mediaType': mediaType,
        'filename': filename,
        'bytes': bytes,
        'caption': caption,
      },
      ack: (dynamic data) {
        if (completer.isCompleted) return;
        if (data is Map) {
          completer.complete(Map<String, dynamic>.from(data));
        } else {
          completer.complete(null);
        }
      },
    );

    _socketLog(
      '[SocketService] sendMediaBytes mediaType=$mediaType bytes=${bytes.length}',
    );

    // 120 s timeout for large files on slow connections.
    return completer.future.timeout(
      const Duration(seconds: 120),
      onTimeout: () => {'ok': false, 'error': 'Timeout'},
    );
  }
  // ── presence ───────────────────────────────────────────────────────────────

  /// Ask the server if [userId] is currently online.
  void checkPresence(String userId) {
    _socket?.emit(SocketEvents.checkPresence, userId);
  }

  // ── generic listener ────────────────────────────────────────────────────

  /// Register a listener for [event]. Returns a dispose callback to unregister.
  DisposeCallback on(String event, JsonCallback cb) {
    void handler(dynamic data) {
      if (data is Map) cb(Map<String, dynamic>.from(data));
    }

    _socket?.on(event, handler);
    return () => _socket?.off(event, handler);
  }

  // ── convenience listeners (delegate to generic on()) ──────────────────

  DisposeCallback onPresenceResult(JsonCallback cb) =>
      on(SocketEvents.presenceResult, cb);

  DisposeCallback onUserOnline(JsonCallback cb) =>
      on(SocketEvents.userOnline, cb);

  DisposeCallback onUserOffline(JsonCallback cb) =>
      on(SocketEvents.userOffline, cb);

  DisposeCallback onNewMessage(JsonCallback cb) =>
      on(SocketEvents.newMessage, cb);

  DisposeCallback onMessageDeleted(JsonCallback cb) =>
      on(SocketEvents.messageDeleted, cb);

  DisposeCallback onTypingStart(JsonCallback cb) =>
      on(SocketEvents.typingStart, cb);

  DisposeCallback onTypingStop(JsonCallback cb) =>
      on(SocketEvents.typingStop, cb);

  DisposeCallback onMessagesRead(JsonCallback cb) =>
      on(SocketEvents.messagesRead, cb);

  DisposeCallback onNewConversation(JsonCallback cb) =>
      on(SocketEvents.newConversation, cb);

  /// Remove all listeners for a specific event (call when leaving a room).
  void off(String event) => _socket?.off(event);

  /// Remove all listeners (call on dispose).
  void offAll() {
    for (final ev in [
      SocketEvents.newMessage,
      SocketEvents.messageDeleted,
      SocketEvents.typingStart,
      SocketEvents.typingStop,
      SocketEvents.messagesRead,
      SocketEvents.newConversation,
      SocketEvents.userOnline,
      SocketEvents.userOffline,
      SocketEvents.presenceResult,
    ]) {
      _socket?.off(ev);
    }
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final socketServiceProvider = Provider<SocketService>((ref) {
  const storage = FlutterSecureStorage();
  final offlineQueue = ref.watch(offlineQueueProvider);
  final svc = SocketService(storage, offlineQueue: offlineQueue);
  ref.onDispose(svc.disconnect);
  return svc;
});
