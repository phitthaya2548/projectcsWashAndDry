import 'dart:convert';

StaffOrderListResponse staffOrderListResponseFromJson(String str) =>
    StaffOrderListResponse.fromJson(json.decode(str));

String staffOrderListResponseToJson(StaffOrderListResponse data) =>
    json.encode(data.toJson());

class StaffOrderListResponse {
  final bool ok;
  final List<StaffOrder> data;

  const StaffOrderListResponse({
    required this.ok,
    required this.data,
  });

  factory StaffOrderListResponse.fromJson(Map<String, dynamic> json) =>
      StaffOrderListResponse(
        ok: json['ok'] ?? false,
        data: (json['data'] as List<dynamic>? ?? [])
            .map((e) => StaffOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'data': data.map((e) => e.toJson()).toList(),
      };
}

class StaffOrder {
  final String id;
  final String status;
  final String serviceType;
  final String? address;
  final String? storeId;
  final String? note;
  final String? detergentOption;
  final String? beforeWashImage;
  final DateTime? orderDatetime; 
  final CustomerInfo? customer;
  final MachineInfo? washer;
  final MachineInfo? dryer;

  const StaffOrder({
    required this.id,
    required this.status,
    required this.serviceType,
    this.address,
    this.storeId,
    this.note,
    this.detergentOption,
    this.beforeWashImage,
    this.orderDatetime, 
    this.customer,
    this.washer,
    this.dryer,
  });

  factory StaffOrder.fromJson(Map<String, dynamic> json) => StaffOrder(
        id: json['id'] ?? json['_id'] ?? '',
        status: json['status'] ?? '',
        serviceType: json['service_type'] ?? '',
        address: json['address'] as String?,
        note: json['note'] as String?,
        storeId: (json['store'] as Map<String, dynamic>?)?['id'] as String?,
        detergentOption: json['detergent_option'] as String?,
        beforeWashImage: json['before_wash_image'] as String?,
        orderDatetime: json['order_datetime'] != null
            ? DateTime.tryParse(json['order_datetime'].toString())?.toLocal()
            : null, 
        customer: json['customer'] != null
            ? CustomerInfo.fromJson(json['customer'] as Map<String, dynamic>)
            : null,
        washer: json['washer'] != null
            ? MachineInfo.fromJson(json['washer'] as Map<String, dynamic>)
            : null,
        dryer: json['dryer'] != null
            ? MachineInfo.fromJson(json['dryer'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'service_type': serviceType,
        'address': address,
        'note': note,
        'store': storeId != null ? {'id': storeId} : null,
        'detergent_option': detergentOption,
        'before_wash_image': beforeWashImage,
        'order_datetime': orderDatetime?.toUtc().toIso8601String(), // เพิ่ม
        'customer': customer?.toJson(),
        'washer': washer?.toJson(),
        'dryer': dryer?.toJson(),
      };
}
class CustomerInfo {
  final String name;
  final String phone;
  final String? profileImage;

  const CustomerInfo({
    required this.name,
    required this.phone,
    this.profileImage,
  });

  factory CustomerInfo.fromJson(Map<String, dynamic> json) => CustomerInfo(
        name: json['name'] ?? '',
        phone: json['phone'] ?? '',
        profileImage: json['profile_image'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'profile_image': profileImage,
      };
}

class MachineInfo {
  final String id;
  final String name;
  final int? capacity;
  final int? workMinutes;
  final int? price;
  final String? status;

  const MachineInfo({
    required this.id,
    required this.name,
    this.capacity,
    this.workMinutes,
    this.price,
    this.status,
  });

  factory MachineInfo.fromJson(Map<String, dynamic> json) => MachineInfo(
        id: json['id'] ?? json['_id'] ?? '',
        name: json['name'] ?? '',
        capacity: (json['capacity'] as num?)?.toInt(),
        workMinutes: (json['work_minutes'] as num?)?.toInt(),
        price: (json['price'] as num?)?.toInt(),
        status: json['status'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'capacity': capacity,
        'work_minutes': workMinutes,
        'price': price,
        'status': status,
      };
}