import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/socket_service.dart';

void main() {
  group('SocketService', () {
    test('reconnectIfNeeded is a no-op before first connect', () async {
      final service = SocketService(const FlutterSecureStorage());

      await service.reconnectIfNeeded();

      expect(service.isConnected, isFalse);
    });

    test('sendMediaBytes returns null when socket is disconnected', () async {
      final service = SocketService(const FlutterSecureStorage());

      final result = await service.sendMediaBytes(
        conversationId: 'conv-1',
        bytes: Uint8List.fromList([1, 2, 3]),
        mediaType: 'image',
        filename: 'test.png',
      );

      expect(result, isNull);
    });
  });
}
