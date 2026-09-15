class AppliedStoreResponse {
  final bool ok;
  final AppliedStoreData? data;
  final String? message;

  AppliedStoreResponse({
    required this.ok,
    this.data,
    this.message,
  });

  factory AppliedStoreResponse.fromJson(Map<String, dynamic> json) {
    return AppliedStoreResponse(
      ok: json['ok'] as bool? ?? false,
      data: json['data'] != null
          ? AppliedStoreData.fromJson(json['data'] as Map<String, dynamic>)
          : null,
      message: json['message'] as String?,
    );
  }
}

class AppliedStoreData {
  final String storeId;
  final String storeName;
  final String phone;
  final String address;
  final String profileImage;
  final String? status;

  AppliedStoreData({
    required this.storeId,
    required this.storeName,
    required this.phone,
    required this.address,
    required this.profileImage,
    required this.status,
  });

  factory AppliedStoreData.fromJson(Map<String, dynamic> json) {
    return AppliedStoreData(
      storeId: json['store_id'] as String? ?? '',
      storeName: json['store_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      address: json['address'] as String? ?? '',
      profileImage: json['profile_image'] as String? ?? '',
      status: json['status'] as String?,
    );
  }

 
  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'รอการยืนยัน';
      case 'TEMP_CLOSED':
        return 'ยืนยันแล้ว';
      case 'ONLINE':
        return 'ใช้งาน';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }
}