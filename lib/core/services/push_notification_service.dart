import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mysme/core/providers/http_client.dart';
import 'package:mysme/firebase_options.dart';

/// Android notification channel for chat messages.
const _androidChannel = AndroidNotificationChannel(
  'mystme_messages',
  'Messages',
  description: 'Notifications de nouveaux messages MystMe',
  importance: Importance.high,
);

/// Callback signature for foreground messages.
/// [data] contains the notification payload (e.g. conversationId).
typedef OnForegroundMessage = void Function(Map<String, dynamic> data);

/// Callback invoked when the user taps a push notification.
/// [data] contains the notification payload.
typedef OnNotificationTap = void Function(Map<String, dynamic> data);

class PushNotificationService {
  PushNotificationService._();

  static bool _initialized = false;
  static bool _notificationsEnabled = true;
  static bool _interactionHandlersBound = false;
  static StreamSubscription<String>? _tokenSub;
  static StreamSubscription<RemoteMessage>? _fgSub;

  static final FlutterLocalNotificationsPlugin _localNotifs =
      FlutterLocalNotificationsPlugin();

  /// Optional callback invoked when a foreground push arrives.
  static OnForegroundMessage? onForegroundMessage;

  /// Optional callback invoked when the user taps a notification
  /// (background or terminated state). Use this to navigate to a chat.
  static OnNotificationTap? onNotificationTap;

  static Future<void> _bindForegroundListener() async {
    await _fgSub?.cancel();
    _fgSub = FirebaseMessaging.onMessage.listen((message) {
      if (_notificationsEnabled) {
        _showLocalNotification(message);
      }

      final data = <String, dynamic>{
        ...message.data,
        if (message.notification != null) ...{
          'title': message.notification!.title,
          'body': message.notification!.body,
        },
      };
      onForegroundMessage?.call(data);
    });
  }

  static Future<void> _disableHandlers() async {
    await _tokenSub?.cancel();
    await _fgSub?.cancel();
    _tokenSub = null;
    _fgSub = null;
    _initialized = false;
  }

  /// Set up a callback to handle notification taps (when app is in background
  /// or terminated). Returns the initial message if the app was opened via a
  /// notification tap.
  static Future<RemoteMessage?> setupInteractionHandlers() async {
    if (!_initialized) return null;

    if (!_interactionHandlersBound) {
      // Background → foreground tap
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleTap(message);
      });
      _interactionHandlersBound = true;
    }

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

  /// Initialize local notifications plugin + Android channel.
  static Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifs.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        // User tapped a local notification — extract payload
        final payload = response.payload;
        if (payload != null &&
            payload.isNotEmpty &&
            onNotificationTap != null) {
          onNotificationTap!({'conversationId': payload});
        }
      },
    );

    // Create the Android notification channel
    if (Platform.isAndroid) {
      await _localNotifs
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  /// Show a local notification (used when the app is in the foreground).
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    final android = AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const ios = DarwinNotificationDetails(
      presentSound: true,
    );
    final details = NotificationDetails(android: android, iOS: ios);

    await _localNotifs.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: message.data['conversationId'] as String?,
    );
  }

  static Future<void> initIfConfigured() async {
    if (_initialized || !_notificationsEnabled) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      await messaging.getToken();

      // Initialize local notifications for foreground display
      await _initLocalNotifications();

      await _bindForegroundListener();

      _initialized = true;
    } catch (_) {
      // Firebase not configured yet in native targets.
      // Keep app functional; initialization can be enabled once config files are added.
    }
  }

  static Future<void> applyUserPreference(
    HttpClient client, {
    required bool enabled,
  }) async {
    _notificationsEnabled = enabled;

    if (!enabled) {
      await _disableHandlers();
      return;
    }

    await initIfConfigured();

    if (!_initialized) return;

    await _bindForegroundListener();
    await setupInteractionHandlers();
    await syncToken(client);
  }

  static Future<void> syncToken(HttpClient client) async {
    if (!_notificationsEnabled) return;

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
