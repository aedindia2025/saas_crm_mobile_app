import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer';

import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  log("Handling a background message: ${message.messageId}");
}

class NotificationService {
  static final FirebaseMessaging _messaging =
      FirebaseMessaging.instance;

  static final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {

    /// BACKGROUND HANDLER
    FirebaseMessaging.onBackgroundMessage(
      _firebaseMessagingBackgroundHandler,
    );

    /// PERMISSION
    NotificationSettings settings =
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus ==
        AuthorizationStatus.authorized) {
      log('User granted permission');
    }

    /// TOKEN
    String? token = await _messaging.getToken();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString("FCM_tokel", token ?? "");

    log("FCM Token: $token");

    /// LOCAL NOTIFICATION INIT
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
    InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,

      /// LOCAL NOTIFICATION CLICK
      onDidReceiveNotificationResponse:
          (NotificationResponse response) {

        log("Local notification tapped");

        _navigateToNotificationList();
      },
    );

    /// FOREGROUND MESSAGE
    FirebaseMessaging.onMessage.listen(
          (RemoteMessage message) {

        log(
          "Message received in foreground: ${message.notification?.title}",
        );

        _showLocalNotification(message);
      },
    );

    /// BACKGROUND CLICK
    FirebaseMessaging.onMessageOpenedApp.listen(
          (RemoteMessage message) {

        log("Notification clicked from background");

        _navigateToNotificationList();
      },
    );

    /// TERMINATED STATE CLICK
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {

      log("App opened from terminated state");

      _navigateToNotificationList();
    }
  }

  static void _navigateToNotificationList() {

    MyApp.navigatorKey.currentState?.pushNamed(
      '/notification-list',
    );
  }

  static void _showLocalNotification(RemoteMessage message) async {

    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',

      channelDescription:
      'This channel is used for important notifications.',

      importance: Importance.max,
      priority: Priority.high,

      ticker: 'ticker',

      /// SMALL ICON
      icon: 'ic_stat_notification',

      /// LARGE ICON
      largeIcon: DrawableResourceAndroidBitmap(
        '@mipmap/ic_launcher',
      ),

      /// EXPANDED STYLE
      styleInformation: BigTextStyleInformation(
        '',
        contentTitle: 'Notification',
        summaryText: 'Tap to open',
      ),

      color: Colors.deepPurple,

      playSound: true,
      enableVibration: true,
      autoCancel: true,

      visibility: NotificationVisibility.public,
    );

    const NotificationDetails details =
    NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      message.hashCode,

      message.notification?.title ?? "New Notification",

      message.notification?.body ?? "",

      details,

      payload: message.data.toString(),
    );
  }
}