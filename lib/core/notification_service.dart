import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  debugPrint("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
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
      debugPrint('Message data: \${message.data}');

      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? 'New Notification',
          body: message.notification!.body ?? '',
        );
      }
    });

    // 4. Save FCM token to Supabase for the current user
    _saveToken();

    // 5. Setup Supabase Realtime for user_notifications
    _setupRealtimeNotifications();
  }

  void _setupRealtimeNotifications() {
    final supabase = Supabase.instance.client;
    final sbUser = Supabase.instance.client.auth.currentUser;
    final fbUser = fb.FirebaseAuth.instance.currentUser;
    final identifier = sbUser?.email ?? fbUser?.phoneNumber;
    if (identifier == null) return;

    final column = identifier.contains('@') ? 'email' : 'phone';

    // We can't filter deeply on a mapped relation, so we listen to all inserts
    // and just filter client-side based on the user's ID.
    supabase.from('users').select('id').eq(column, identifier).maybeSingle().then((userRow) {
      if (userRow == null) return;
      final userId = userRow['id'];

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
    }).catchError((e) {
      debugPrint('Error setting up realtime notifications: $e');
    });
  }

  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    debugPrint('Notification clicked: \${response.payload}');
  }

  Future<void> _saveToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      if (token == null) return;

      final sbUser = Supabase.instance.client.auth.currentUser;
      final fbUser = fb.FirebaseAuth.instance.currentUser;
      final identifier = sbUser?.email ?? fbUser?.phoneNumber;
      if (identifier == null) return;

      final column = identifier.contains('@') ? 'email' : 'phone';

      final supabase = Supabase.instance.client;
      await supabase
          .from('users')
          .update({'fcm_token': token})
          .eq(column, identifier);
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
