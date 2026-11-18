import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/core/services/transfer_service.dart';

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.status, this.body);
  final int status;
  final Object body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    lastRequest = options;
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const storage = FlutterSecureStorage();

  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('extractCode', () {
    test('accepts the formats produced by the PWA and typed by users', () {
      expect(TransferService.extractCode('MYSTME:ABCD-2345'), 'ABCD-2345');
      expect(TransferService.extractCode('  mystme abcd2345 '), 'ABCD-2345');
      expect(TransferService.extractCode('abcd-2345'), 'ABCD-2345');
      expect(TransferService.extractCode('transfer=WXYZ-6789'), 'WXYZ-6789');
    });

    test('rejects text that is not a transfer code', () {
      expect(TransferService.extractCode(null), isNull);
      expect(TransferService.extractCode(''), isNull);
      expect(TransferService.extractCode('hello world'), isNull);
      expect(TransferService.extractCode('ABCD-0000'),
          isNull); // 0 not in alphabet
      expect(TransferService.extractCode('https://example.com'), isNull);
    });
  });

  test('codeFromReferrer reads the transfer param among others', () {
    expect(
      TransferService.codeFromReferrer(
          'utm_source=google-play&transfer=ABCD-2345&utm_medium=organic'),
      'ABCD-2345',
    );
    expect(TransferService.codeFromReferrer('utm_source=google-play'), isNull);
    expect(TransferService.codeFromReferrer(null), isNull);
  });

  test('install referrer is read only once per install', () async {
    var reads = 0;
    final service = TransferService(
      HttpClient(storage),
      storage,
      isAndroid: true,
      installReferrerReader: () async {
        reads++;
        return 'transfer=ABCD-2345';
      },
    );

    expect(await service.readInstallReferrerCodeOnce(), 'ABCD-2345');
    expect(await service.readInstallReferrerCodeOnce(), isNull);
    expect(reads, 1);
  });

  test('install referrer is skipped outside Android and never throws',
      () async {
    final ios = TransferService(HttpClient(storage), storage,
        isAndroid: false,
        installReferrerReader: () async => 'transfer=ABCD-2345');
    expect(await ios.readInstallReferrerCodeOnce(), isNull);

    final broken = TransferService(HttpClient(storage), storage,
        isAndroid: true,
        installReferrerReader: () async => throw Exception('no Play services'));
    expect(await broken.readInstallReferrerCodeOnce(), isNull);
  });

  test('claim posts the normalized code and returns conversation ids',
      () async {
    final client = HttpClient(storage);
    final adapter = _RecordingAdapter(200, {
      'ok': true,
      'conversationIds': ['c1', 'c2'],
    });
    client.dio.httpClientAdapter = adapter;

    final result =
        await TransferService(client, storage).claim('mystme:abcd2345');

    expect(adapter.lastRequest?.path, '/identity/transfer/claim');
    expect(adapter.lastRequest?.data, {'code': 'ABCD-2345'});
    expect(result.conversationIds, ['c1', 'c2']);
  });

  test('a rejected code surfaces as ApiException with its status', () async {
    final client = HttpClient(storage);
    client.dio.httpClientAdapter = _RecordingAdapter(409, {
      'message': 'Ce code a déjà été utilisé',
      'code': 'TRANSFER_CODE_USED',
    });

    await expectLater(
      TransferService(client, storage).claim('ABCD-2345'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 409)
          .having((e) => e.message, 'message', 'Ce code a déjà été utilisé')),
    );
  });
}
