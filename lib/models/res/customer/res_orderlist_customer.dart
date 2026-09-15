class OrderItem {
  final String orderId;
  final String serviceType;
  final String customerFullname;
  final String customerPhone;
  final String addressFull;
  final Map<String, dynamic>? orderDatetime;
  final String initialStatus;
  final bool isReviewed;

  const OrderItem({
    required this.orderId,
    required this.serviceType,
    required this.customerFullname,
    required this.customerPhone,
    required this.addressFull,
    required this.orderDatetime,
    required this.initialStatus,
    required this.isReviewed,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
    orderId: j['order_id'] as String? ?? '',
    serviceType: j['service_type'] as String? ?? '',
    customerFullname: j['customer_fullname'] as String? ?? '-',
    customerPhone: j['customer_phone'] as String? ?? '-',
    addressFull: j['address_full'] as String? ?? '-',
    orderDatetime: j['order_datetime'] as Map<String, dynamic>?,
    initialStatus: j['status'] as String? ?? '',
    isReviewed: j['is_reviewed'] as bool? ?? false,
  );
}

class OrderSummary {
  final int total;
  final int successCount;
  final int cancelledCount;
  final Map<String, int> byStatus;

  const OrderSummary({
    required this.total,
    required this.successCount,
    required this.cancelledCount,
    required this.byStatus,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> j) => OrderSummary(
    total: j['total'] as int? ?? 0,
    successCount: j['success_count'] as int? ?? 0,
    cancelledCount: j['cancelled_count'] as int? ?? 0,
    byStatus: (j['by_status'] as Map<String, dynamic>?)?.map(
      (k, v) => MapEntry(k, v as int),
    ) ?? {},
  );
}

class CustomerOrderListResponse {
  final List<OrderItem> data;
  final OrderSummary summary;

  const CustomerOrderListResponse({
    required this.data,
    required this.summary,
  });

  factory CustomerOrderListResponse.fromJson(Map<String, dynamic> j) =>
      CustomerOrderListResponse(
        data: (j['data'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        summary: OrderSummary.fromJson(
          j['summary'] as Map<String, dynamic>? ?? {},
        ),
      );
}