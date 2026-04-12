import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../router.dart';
import '../features/pairing/us_state.dart';
import 'package:go_router/go_router.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  debugPrint("Handling a background message: ${message.messageId}");
  // If we send data-only messages, we'd need to show a local notification here.
  // But for now, we'll rely on the OS to show 'notification' messages.
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  late final ProviderContainer _container;

  Future<void> init(ProviderContainer container) async {
    _container = container;
    // 1. Initialize local notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
    );

    // 2. Request FCM permissions
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted notification permission');
    }

    // 3. Setup background and foreground handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? 'New Notification',
          body: message.notification!.body ?? '',
          payload: message.data['type'], // Pass type as payload for local notifications
        );
      }
    });

    // 4. Handle notification clicks when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification clicked (background): ${message.data}');
      _handleNotificationClick(message.data);
    });

    // 5. Check if app was opened from a terminated state via notification
    _firebaseMessaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('App opened from terminated state via notification: ${message.data}');
        _handleNotificationClick(message.data);
      }
    });

    // 6. Save FCM token to Supabase for the current user
    _saveToken();

    // 7. Setup Supabase Realtime for user_notifications
    _setupRealtimeNotifications();
  }

  void _setupRealtimeNotifications() {
    final supabase = Supabase.instance.client;
    final sbUser = Supabase.instance.client.auth.currentUser;
    if (sbUser == null) return;

    final userId = sbUser.id;

    supabase
        .channel('public:user_notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'user_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            if (newRecord.isNotEmpty) {
              showLocalNotification(
                title: newRecord['title'] ?? 'Notification',
                body: newRecord['body'] ?? '',
              );
            }
          },
        )
        .subscribe();
    debugPrint('Subscribed to Realtime user_notifications for user $userId');
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('Notification clicked: ${response.payload}');
    if (response.payload != null) {
      try {
        // We'll try to parse the payload as a JSON map if it looks like one
        if (response.payload!.startsWith('{')) {
          final Map<String, dynamic> data = jsonDecode(response.payload!);
          _handleNotificationClick(data);
        } else {
          // Fallback for simple string types
          _handleNotificationClick({'type': response.payload});
        }
      } catch (e) {
        _handleNotificationClick({'type': response.payload});
      }
    }
  }

  void _handleNotificationClick(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == null) return;

    debugPrint('Handling notification click of type: $type with data: $data');

    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint('Could not navigate: rootNavigatorKey.currentContext is null');
      return;
    }

    switch (type) {
      case 'shared_post':
      case 'shared_journal':
        _container.read(sharedPostsProvider.notifier).refresh();
        context.go('/us?section=feed');
        break;
      case 'partner_checkin':
        context.go('/dashboard');
        break;
      case 'daily_insight':
        context.go('/insights');
        break;
      case 'gentle_reminder':
        context.go('/dashboard');
        break;
      case 'daily_question':
      case 'daily_question_answer':
      case 'partner_review_submitted':
        context.go('/us?section=chat');
        break;
      case 'cycle_reminder':
        context.go('/cycle_calendar');
        break;
      case 'dream_update':
        final dreamId = data['dream_id'] ?? data['id'];
        if (dreamId != null) {
          context.push('/us/dream/$dreamId');
        } else {
          context.go('/us?section=dreams');
        }
        break;
      default:
        debugPrint('Unknown notification type: $type');
        context.go('/dashboard');
    }
  }

  Future<void> _saveToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final sbUser = Supabase.instance.client.auth.currentUser;
      if (sbUser == null) return;

      final userId = sbUser.id;
      final supabase = Supabase.instance.client;
      await supabase
          .from('users')
          .update({'fcm_token': token})
          .eq('id', userId);
      debugPrint('Saved FCM token to database');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'zuno_channel_id',
      'Zuno Notifications',
      channelDescription: 'Notifications from Zuno app',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id: 0, // Notification ID
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }
}
