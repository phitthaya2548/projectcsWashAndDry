import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_notification_customer.dart';
import 'package:wash_and_dry/service/session_service.dart';

class NotificationApiService {
  static String? _url;

  static Future<String> _getBaseUrl() async {
    if (_url != null && _url!.isNotEmpty) {
      return _url!;
    }

    final config = await Configuration.getConfig();
    final u = (config['apiEndpoint'] ?? '').toString().trim();

    if (u.isEmpty) {
      throw Exception('ไม่พบ apiEndpoint ใน config');
    }

    _url = u;

    return u;
  }

  static Future<String> getCustomerId() async {
    final id = await Session().getCustomerId();

    if (id == null || id.isEmpty) {
      throw Exception(
        "ไม่พบ customerId (ยังไม่ได้ล็อกอิน)",
      );
    }

    return id;
  }

  static Future<List<NotificationModel>> getHistory({
    required String userId,
    required String userRole,
    int limit = 20,
  }) async {
    final baseUrl = await _getBaseUrl();

    final uri = Uri.parse(
      '$baseUrl/notification/history',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'user_role': userRole,
        'limit': limit.toString(),
      },
    );

    final res = await http.get(uri);

    final json = jsonDecode(res.body);

    if (
        res.statusCode != 200 ||
        json['ok'] != true
    ) {
      throw Exception(
        json['message'] ??
            'โหลดประวัติแจ้งเตือนไม่สำเร็จ',
      );
    }

    final List list = json['data'] ?? [];

    return list
        .map(
          (e) => NotificationModel.fromJson(e),
        )
        .toList();
  }

  static Future<List<NotificationModel>> getMyHistory({
    int limit = 20,
  }) async {
    final customerId = await getCustomerId();

    return getHistory(
      userId: customerId,
      userRole: 'customer',
      limit: limit,
    );
  }

  static Future<int> getUnreadCount({
    required String userId,
    required String userRole,
  }) async {
    final baseUrl = await _getBaseUrl();

    final uri = Uri.parse(
      '$baseUrl/notification/unread_count',
    ).replace(
      queryParameters: {
        'user_id': userId,
        'user_role': userRole,
      },
    );

    final res = await http.get(uri);

    final json = jsonDecode(res.body);

    if (
        res.statusCode != 200 ||
        json['ok'] != true
    ) {
      return 0;
    }

    final count = json['data']?['count'];

    if (count is int) {
      return count;
    }

    return int.tryParse(
          count?.toString() ?? '0',
        ) ??
        0;
  }

  static Future<int> getMyUnreadCount() async {
    final customerId = await getCustomerId();

    return getUnreadCount(
      userId: customerId,
      userRole: 'customer',
    );
  }

  static Future<void> markAsRead(
    String notificationId,
  ) async {
    final baseUrl = await _getBaseUrl();

    final uri = Uri.parse(
      '$baseUrl/notification/mark-read',
    );

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'notification_id': notificationId,
      }),
    );

    final json = jsonDecode(res.body);

    if (
        res.statusCode != 200 ||
        json['ok'] != true
    ) {
      throw Exception(
        json['message'] ??
            'มาร์คว่าอ่านแล้วไม่สำเร็จ',
      );
    }
  }

  static Future<void> markAllAsRead({
    required String userId,
    required String userRole,
  }) async {
    final baseUrl = await _getBaseUrl();

    final uri = Uri.parse(
      '$baseUrl/notification/mark-all-read',
    );

    final res = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_id': userId,
        'user_role': userRole,
      }),
    );

    final json = jsonDecode(res.body);

    if (
        res.statusCode != 200 ||
        json['ok'] != true
    ) {
      throw Exception(
        json['message'] ??
            'อ่านทั้งหมดไม่สำเร็จ',
      );
    }
  }
}