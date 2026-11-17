import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/utils/helpers.dart';

void main() {
  group('Helpers.friendlyErrorMessage', () {
    test('keeps session lost message readable', () {
      final message = Helpers.friendlyErrorMessage(
        SessionLostException(),
      );

      expect(message, contains('Session perdue'));
    });

    test('maps rate limiting to a clear user message', () {
      final message = Helpers.friendlyErrorMessage(
        ApiException('Too many requests', 429),
      );

      expect(message,
          'Trop de tentatives. Patiente un instant avant de réessayer.');
    });

    test('maps network failures to a clear connection message', () {
      final message = Helpers.friendlyErrorMessage(
        const SocketException('Failed host lookup'),
      );

      expect(message,
          'Connexion internet indisponible. Vérifie ton réseau puis réessaie.');
    });

    test('hides technical exception strings behind fallback copy', () {
      final message = Helpers.friendlyErrorMessage(
        Exception('SocketException: Connection refused'),
        fallback: 'Action impossible pour le moment.',
      );

      expect(message, 'Action impossible pour le moment.');
    });
  });
}
