import 'dart:io';

import 'package:dio/dio.dart';
import 'package:mysme/core/providers/http_client.dart';

bool isOfflineSendError(Object error) {
  if (error is SocketException) {
    return true;
  }

  if (error is DioException) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout;
  }

  if (error is ApiException) {
    if (error.statusCode == 0) {
      return true;
    }

    final message = error.message.toLowerCase();
    return message.contains('sockete') ||
        message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('failed host lookup') ||
        message.contains('connection refused') ||
        message.contains('connection error') ||
        message.contains('network is unreachable');
  }

  final message = error.toString().toLowerCase();
  return message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('connection refused') ||
      message.contains('connection error') ||
      message.contains('network is unreachable') ||
      message.contains('timeout') ||
      message.contains('timed out');
}
