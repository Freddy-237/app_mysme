import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/firebase_options.dart';

/// Callback signature for foreground messages.
/// [data] contains the notification payload (e.g. conversationId).
typedef OnForegroundMessage = void Function(Map<String, dynamic> data);

/// Callback invoked when the user taps a push notification.
/// [data] contains the notification payload.
typedef OnNotificationTap = void Function(Map<String, dynamic> data);

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _fgSub;

  /// Optional callback invoked when a foreground push arrives.
  static OnForegroundMessage? onForegroundMessage;

  /// Optional callback invoked when the user taps a notification
  /// (background or terminated state). Use this to navigate to a chat.
  static OnNotificationTap? onNotificationTap;

  /// Set up a callback to handle notification taps (when app is in background
  /// or terminated). Returns the initial message if the app was opened via a
  /// notification tap.
  static Future<RemoteMessage?> setupInteractionHandlers() async {
    if (!_initialized) return null;

    // Background → foreground tap
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleTap(message);
    });

    // Terminated → opened via notification tap
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleTap(initial);
    return initial;
  }

  static void _handleTap(RemoteMessage message) {
    final data = message.data;
    if (onNotificationTap != null) {
      onNotificationTap!(data);
    } else {
      // Fallback — forward to foreground handler
      onForegroundMessage?.call(data);
    }
  }

  static Future<void> initIfConfigured() async {
    if (_initialized) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.getToken();

      // Foreground message handler — notify listeners
      await _fgSub?.cancel();
      _fgSub = FirebaseMessaging.onMessage.listen((message) {
        final data = <String, dynamic>{
          ...message.data,
          if (message.notification != null) ...{
            'title': message.notification!.title,
            'body': message.notification!.body,
          },
        };
        onForegroundMessage?.call(data);
      });

      _initialized = true;
    } catch (_) {
      // Firebase not configured yet in native targets.
      // Keep app functional; initialization can be enabled once config files are added.
    }
  }

  static Future<void> syncToken(HttpClient client) async {
    if (!_initialized) {
      await initIfConfigured();
    }

    if (!_initialized) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await client.patch('/identity/push-token', {'token': token});
      }

      // Register listener only once — cancel previous if any
      await _tokenSub?.cancel();
      _tokenSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (newToken.isEmpty) return;
        try {
          await client.patch('/identity/push-token', {'token': newToken});
        } catch (_) {}
      });
    } catch (_) {}
  }
}
