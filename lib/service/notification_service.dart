import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_order_detail_screen.dart';
import 'package:wash_and_dry/screens/store/store_befororder_detail_screen.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  print('Background Message ID: ${message.messageId}');
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Data: ${message.data}');
}

class NotificationService {
  static final NotificationService _instance =
      NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FirebaseMessaging _fcm =
      FirebaseMessaging.instance;

  final FlutterLocalNotificationsPlugin
      _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const String _channelId =
      'order_notification_v2';

  static const String _channelName =
      'Default Notification';

  static const String _channelDescription =
      'Notification Channel';

  final StreamController<String?>
      _orderUpdateController =
      StreamController<String?>.broadcast();

  Stream<String?> get onOrderUpdate =>
      _orderUpdateController.stream;

  void notifyOrderUpdate([
    String? orderId,
  ]) {
    if (!_orderUpdateController.isClosed) {
      _orderUpdateController.add(orderId);
    }
  }

  void dispose() {
    _orderUpdateController.close();
  }

  Future<void> initialize() async {
    final settings =
        await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    print(
      "Permission : ${settings.authorizationStatus}",
    );

    await _initLocalNotifications();
    await _createAndroidChannel();

    final token = await _fcm.getToken();

    print("FCM TOKEN : $token");

    _fcm.onTokenRefresh.listen(
      (newToken) {
        print("NEW TOKEN : $newToken");
      },
    );

    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
    );

    FirebaseMessaging.onMessageOpenedApp.listen(
      _handleNotificationTap,
    );

    final initialMessage =
        await _fcm.getInitialMessage();

    if (initialMessage != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) {
          _handleNotificationTap(
            initialMessage,
          );
        },
      );
    }
  }

  Future<void> _initLocalNotifications() async {
    const android =
        AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const ios =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings =
        InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse:
          (details) {
        print(
          "Notification Click : ${details.payload}",
        );

        _navigateFromPayload(
          details.payload,
        );
      },
    );
  }

  Future<void> _createAndroidChannel() async {
    const channel =
        AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound:
          RawResourceAndroidNotificationSound(
        'notification_sound',
      ),
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          channel,
        );
  }

  String _getRole(
    Map<String, dynamic> data,
  ) {
    final role =
        data['role']?.toString() ??
        data['target_role']?.toString();

    if (role == null ||
        role.trim().isEmpty) {
      return 'customer';
    }

    return role.trim().toLowerCase();
  }

  void _handleForegroundMessage(
    RemoteMessage message,
  ) {
    print("Foreground Notification");
    print(message.notification?.title);
    print(message.data);

    final notification =
        message.notification;

    final orderId =
        message.data['order_id']
            ?.toString();

    final role =
        _getRole(
      message.data,
    );

    notifyOrderUpdate(
      orderId,
    );

    if (notification == null) {
      return;
    }

    final notificationId =
        DateTime.now()
            .millisecondsSinceEpoch
            .remainder(
              100000,
            );

    final payload =
        jsonEncode({
      'order_id': orderId ?? '',
      'role': role,
    });

    _localNotifications.show(
      notificationId,
      notification.title,
      notification.body,
      NotificationDetails(
        android:
            AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription:
              _channelDescription,
          importance: Importance.max,
          priority: Priority.high,
          icon:
              '@mipmap/ic_launcher',
          sound: const RawResourceAndroidNotificationSound(
            'notification_sound',
          ),
          styleInformation:
              BigTextStyleInformation(
            notification.body ?? '',
            contentTitle:
                notification.title,
            summaryText:
                'แตะเพื่อดูรายละเอียดออเดอร์',
          ),
          color:
              const Color(
            0xFFEA5B0C,
          ),
          colorized: false,
          groupKey:
              'order_notifications',
        ),
        iOS:
            const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          attachments: null,
          subtitle:
              'แตะเพื่อดูรายละเอียดออเดอร์',
          threadIdentifier:
              'order_notifications',
        ),
      ),
      payload: payload,
    );
  }

  void _handleNotificationTap(
    RemoteMessage message,
  ) {
    print(
      "Click Notification",
    );

    print(
      message.data,
    );

    final orderId =
        message.data['order_id']
            ?.toString();

    final role =
        _getRole(
      message.data,
    );

    notifyOrderUpdate(
      orderId,
    );

    _navigateToOrderDetail(
      orderId: orderId,
      role: role,
    );
  }

  void _navigateFromPayload(
    String? payload,
  ) {
    if (payload == null ||
        payload.isEmpty) {
      return;
    }

    try {
      final decoded =
          jsonDecode(payload);

      if (decoded is! Map) {
        return;
      }

      final data =
          Map<String, dynamic>.from(
        decoded,
      );

      final orderId =
          data['order_id']
              ?.toString();

      final role =
          _getRole(
        data,
      );

      notifyOrderUpdate(
        orderId,
      );

      _navigateToOrderDetail(
        orderId: orderId,
        role: role,
      );
    } catch (e) {
      print(
        "Notification payload error: $e",
      );

      notifyOrderUpdate(
        payload,
      );

      _navigateToOrderDetail(
        orderId: payload,
        role: 'customer',
      );
    }
  }

  void _navigateToOrderDetail({
    required String? orderId,
    required String role,
  }) {
    if (orderId == null ||
        orderId.isEmpty) {
      print(
        "ไม่มี order_id ใน notification",
      );

      return;
    }

    final normalizedRole =
        role.trim().toLowerCase();

    print(
      "Navigate notification role: $normalizedRole",
    );

    print(
      "Navigate notification order: $orderId",
    );

    switch (normalizedRole) {
      case 'store':
        Get.to(
          () =>
              StoreOrderDetailScreen(
            orderId: orderId,
          ),
        );
        break;

      case 'customer':
        Get.to(
          () =>
              CustomerOrderDetailScreen(
            orderId: orderId,
          ),
        );
        break;

      default:
        print(
          "ไม่รองรับ notification role: $normalizedRole",
        );
        break;
    }
  }

  Future<String?> getToken() async {
    return await _fcm.getToken();
  }

  Future<void> subscribeToTopic(
    String topic,
  ) async {
    await _fcm.subscribeToTopic(
      topic,
    );

    print(
      "Subscribe : $topic",
    );
  }

  Future<void> unsubscribeFromTopic(
    String topic,
  ) async {
    await _fcm.unsubscribeFromTopic(
      topic,
    );
  }
}