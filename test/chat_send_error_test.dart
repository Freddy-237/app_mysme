import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/features/chat/chat_send_error.dart';

void main() {
  group('isOfflineSendError', () {
    test('returns true for socket exceptions', () {
      expect(
        isOfflineSendError(const SocketException('Failed host lookup')),
        isTrue,
      );
    });

    test('returns true for api exceptions without status code', () {
      expect(
        isOfflineSendError(ApiException('Délai de connexion dépassé', 0)),
        isTrue,
      );
    });

    test('returns false for rate limit api exceptions', () {
      expect(
        isOfflineSendError(ApiException('Trop de requêtes', 429)),
        isFalse,
      );
    });

    test('returns true for dio connection errors', () {
      final error = DioException(
        requestOptions: RequestOptions(path: '/message'),
        type: DioExceptionType.connectionError,
      );

      expect(isOfflineSendError(error), isTrue);
    });
  });
}
