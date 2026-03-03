import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:cloud_functions/cloud_functions.dart';

class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Request permission for notifications
    await _requestPermissions();

    // Initialize local notifications for foreground handling
    await _initializeLocalNotifications();

    // Configure FCM
    await _configureFCM();

    // Subscribe to all users topic
    await subscribeToAllUsers();

    print('✅ Push Notification Service initialized');
  }

  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Push notification permissions granted');
    } else {
      print('❌ Push notification permissions denied');
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap
        print('Push notification tapped: ${response.payload}');
      },
    );
  }

  Future<void> _configureFCM() async {
    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
  }

  Future<void> subscribeToAllUsers() async {
    try {
      await _firebaseMessaging.subscribeToTopic('all_users');
      print('✅ Subscribed to all_users topic');
    } catch (e) {
      print('❌ Failed to subscribe to all_users topic: $e');
    }
  }

  Future<void> unsubscribeFromAllUsers() async {
    try {
      await _firebaseMessaging.unsubscribeFromTopic('all_users');
      print('✅ Unsubscribed from all_users topic');
    } catch (e) {
      print('❌ Failed to unsubscribe from all_users topic: $e');
    }
  }

  Future<String?> getToken() async {
    try {
      String? token = await _firebaseMessaging.getToken();
      print('FCM Token: $token');
      return token;
    } catch (e) {
      print('❌ Failed to get FCM token: $e');
      return null;
    }
  }

  // Secure method to send push notifications via Cloud Functions - only admins can call this
  // Uses Firebase Cloud Functions to avoid exposing FCM server keys on client side
  Future<void> sendHotDealNotification(
    String dealTitle,
    bool isUserAdmin,
  ) async {
    // Security check: Only admins can send notifications
    if (!isUserAdmin) {
      print('❌ Security: Only admins can send push notifications');
      return;
    }

    try {
      // Call Firebase Cloud Function to send notifications
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'sendHotDealNotification',
      );

      final result = await callable.call(<String, dynamic>{
        'dealTitle': dealTitle,
        'timestamp': DateTime.now().toIso8601String(),
      });

      print('✅ Hot deal notification sent via Cloud Functions!');
      print('📊 Cloud Function response: ${result.data}');
    } catch (e) {
      print('❌ Error calling Cloud Function: $e');
      print(
        '💡 Make sure Cloud Functions are deployed and Firebase project is on Blaze plan',
      );
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    print('📱 Foreground message received: ${message.notification?.title}');

    // Show local notification for foreground messages
    _showLocalNotification(
      title: message.notification?.title ?? 'New Notification',
      body: message.notification?.body ?? '',
      payload: jsonEncode(message.data),
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    print('📱 Message opened app: ${message.notification?.title}');
    // Handle navigation or other actions when notification is tapped
  }

  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'push_notifications_channel',
          'Push Notifications',
          channelDescription: 'Push notifications from FCM',
          importance: Importance.high,
          priority: Priority.high,
          showWhen: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }
}

// Background message handler (must be top-level function)
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('📱 Background message received: ${message.notification?.title}');
  // Handle background messages if needed
}
