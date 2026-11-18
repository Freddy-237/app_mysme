import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mysme/core/providers/http_client.dart';

/// Miscellaneous helper utilities.
abstract class Helpers {
  /// Format a [Duration] as mm:ss.
  static String formatCountdown(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Show a lightweight snack bar.
  static void showSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static String friendlyErrorMessage(
    Object error, {
    String fallback = 'Une erreur est survenue. Réessaie dans un instant.',
  }) {
    if (error is SessionLostException) {
      return error.message;
    }

    if (error is ApiException) {
      switch (error.statusCode) {
        case 400:
          final sanitized = _sanitizeMessage(error.message);
          return sanitized ??
              'La demande est invalide. Vérifie les informations saisies.';
        case 401:
          return 'Ta session a expiré. Reconnecte-toi ou restaure ton compte.';
        case 403:
          return 'Cette action n\'est pas autorisée.';
        case 404:
          return 'Le contenu demandé est introuvable.';
        case 409:
          return 'Cette action est déjà en cours ou a déjà été effectuée.';
        case 429:
          return 'Trop de tentatives. Patiente un instant avant de réessayer.';
        default:
          if (error.statusCode >= 500) {
            return 'Le service est temporairement indisponible. Réessaie plus tard.';
          }
          final sanitized = _sanitizeMessage(error.message);
          return sanitized ?? fallback;
      }
    }

    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'La connexion prend trop de temps. Réessaie dans un instant.';
        case DioExceptionType.connectionError:
          return 'Connexion internet indisponible. Vérifie ton réseau puis réessaie.';
        case DioExceptionType.badCertificate:
        case DioExceptionType.badResponse:
        case DioExceptionType.cancel:
        case DioExceptionType.unknown:
          final nested = error.error;
          if (nested != null && nested != error) {
            return friendlyErrorMessage(nested, fallback: fallback);
          }
          break;
      }
    }

    if (error is SocketException) {
      return 'Connexion internet indisponible. Vérifie ton réseau puis réessaie.';
    }

    if (error is TimeoutException) {
      return 'Le service met trop de temps à répondre. Réessaie dans un instant.';
    }

    final sanitized = _sanitizeMessage(error.toString());
    return sanitized ?? fallback;
  }

  static void showErrorSnack(
    BuildContext context,
    Object error, {
    String fallback = 'Une erreur est survenue. Réessaie dans un instant.',
  }) {
    showSnack(
      context,
      friendlyErrorMessage(error, fallback: fallback),
      isError: true,
    );
  }

  static String? _sanitizeMessage(String? rawMessage) {
    if (rawMessage == null) return null;

    final message = rawMessage.trim();
    if (message.isEmpty) return null;

    final lowered = message.toLowerCase();
    const technicalMarkers = <String>[
      'exception',
      'socketexception',
      'dioexception',
      'xmlhttprequest',
      'stack trace',
      'handshakeexception',
      'clientexception',
      'errno',
      'status code of',
      'failed host lookup',
      'connection refused',
      'network is unreachable',
    ];

    if (technicalMarkers.any(lowered.contains)) {
      return null;
    }

    if (lowered.contains('timeout')) {
      return 'La connexion prend trop de temps. Réessaie dans un instant.';
    }

    if (lowered.contains('network') ||
        lowered.contains('réseau') ||
        lowered.contains('internet') ||
        lowered.contains('connexion')) {
      return 'Connexion internet indisponible. Vérifie ton réseau puis réessaie.';
    }

    return message;
  }

  /// Returns initials from a display name (max 2 chars).
  static String initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.substring(0, name.length >= 2 ? 2 : name.length).toUpperCase();
  }
}
