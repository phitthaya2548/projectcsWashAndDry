abstract class HistoryItem {
  final String type;
  final DateTime datetime;

  HistoryItem({
    required this.type,
    required this.datetime,
  });
}

DateTime _parseDatetime(dynamic raw) {
  if (raw is String) return DateTime.parse(raw).toLocal();
  if (raw is Map && raw['_seconds'] != null) {
    return DateTime.fromMillisecondsSinceEpoch((raw['_seconds'] as int) * 1000);
  }
  throw FormatException('Invalid datetime format: $raw');
}

class TopupHistoryItem extends HistoryItem {
  final String topupId;
  final int amount;

  TopupHistoryItem({
    required this.topupId,
    required this.amount,
    required DateTime topupDatetime,
  }) : super(type: "topup", datetime: topupDatetime);

  factory TopupHistoryItem.fromJson(Map<String, dynamic> json) {
    return TopupHistoryItem(
      topupId: json['topup_id'] as String,
      amount: (json['amount'] as num).toInt(),
      topupDatetime: _parseDatetime(json['topup_datetime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'topup_id': topupId,
      'type': type,
      'amount': amount,
      'topup_datetime': datetime.toIso8601String(),
    };
  }
}

class PaidOrderHistoryItem extends HistoryItem {
  final String orderId;
  final String serviceType;
  final int totalAmount;

  PaidOrderHistoryItem({
    required this.orderId,
    required this.serviceType,
    required this.totalAmount,
    required DateTime orderDatetime,
  }) : super(type: "payment", datetime: orderDatetime);

  factory PaidOrderHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaidOrderHistoryItem(
      orderId: json['order_id'] as String,
      serviceType: json['service_type'] as String,
      totalAmount: (json['total_amount'] as num).toInt(),
      orderDatetime: _parseDatetime(json['order_datetime']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order_id': orderId,
      'type': type,
      'service_type': serviceType,
      'total_amount': totalAmount,
      'order_datetime': datetime.toIso8601String(),
    };
  }
}

class HistoryResponse<T> {
  final bool ok;
  final String message;
  final List<T> data;

  HistoryResponse({
    required this.ok,
    required this.message,
    required this.data,
  });

  factory HistoryResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return HistoryResponse<T>(
      ok: json['ok'] as bool,
      message: json['message'] as String,
      data: (json['data'] as List<dynamic>)
          .map((e) => fromJsonT(e as Map<String, dynamic>))
          .toList(),
    );
  }
}