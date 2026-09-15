class NotificationModel {
  final String id;
  final String userId;
  final String userRole;
  final String title;
  final String body;
  final String? orderId;
  final bool isRead;
  final DateTime createdAt;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.userRole,
    required this.title,
    required this.body,
    this.orderId,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userRole: json['user_role']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      orderId: json['order_id']?.toString(),
      isRead: json['is_read'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(
                json['created_at'].toString(),
              ) ??
              DateTime.now()
          : DateTime.now(),
    );
  }
}