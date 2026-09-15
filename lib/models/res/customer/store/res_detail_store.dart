import 'dart:convert';

StoreDetail storeDetailFromJson(String str) =>
    StoreDetail.fromJson(json.decode(str));

String storeDetailToJson(StoreDetail data) =>
    json.encode(data.toJson());

class StoreDetail {
  final String storeId;
  final String storeName;
  final String status;
  final String openingHours;
  final String closedHours;
  final double serviceRadius;
  final double rating;
  final String address;
  final String phone;
  final String email;
  final String facebook;
  final String lineId;
  final double latitude;
  final double longitude;
  final String profileImage;
  final int detergentprice;
  final double min_delivery_price;
  final double max_delivery_price;
  final int machineWashCount;
  final int machineDryCount;

  int get totalMachineCount => machineWashCount + machineDryCount;

  const StoreDetail({
    required this.storeId,
    required this.storeName,
    this.status = 'OPEN',
    required this.openingHours,
    required this.closedHours,
    required this.serviceRadius,
    this.rating = 0,
    required this.address,
    required this.phone,
    required this.email,
    required this.facebook,
    required this.lineId,
    required this.latitude,
    required this.longitude,
    this.profileImage = '',
    required this.machineWashCount,
    required this.min_delivery_price,
    required this.max_delivery_price,
    required this.machineDryCount,
    required this.detergentprice,
  });

  factory StoreDetail.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] ?? json) as Map<String, dynamic>;

    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return StoreDetail(
      storeId: data['store_id']?.toString() ?? '',
      storeName: data['store_name']?.toString() ?? '',
      status: data['status']?.toString() ?? 'OPEN',
      openingHours: data['opening_hours']?.toString() ?? '',
      closedHours: data['closed_hours']?.toString() ?? '',
      serviceRadius: toDouble(data['service_radius']),
      rating: toDouble(data['rating']),
      address: data['address']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      facebook: data['facebook']?.toString() ?? '',
      lineId: data['line_id']?.toString() ?? '',
      latitude: toDouble(data['latitude']),
      longitude: toDouble(data['longitude']),
      profileImage: data['profile_image']?.toString() ?? '',
      machineWashCount: toInt(data['machine_wash_count']),
       min_delivery_price: toDouble(data['min_delivery']),
  max_delivery_price: toDouble(data['max_delivery']), 
      machineDryCount: toInt(data['machine_dry_count']),
      detergentprice: toInt(data['detergent_price']),
    );
  }

  Map<String, dynamic> toJson() => {
        'store_id': storeId,
        'store_name': storeName,
        'status': status,
        'opening_hours': openingHours,
        'closed_hours': closedHours,
        'service_radius': serviceRadius,
        'rating': rating,
        'address': address,
        'phone': phone,
        'email': email,
        'facebook': facebook,
        'line_id': lineId,
        'latitude': latitude,
        'longitude': longitude,
        'profile_image': profileImage,
        'min_delivery_price': min_delivery_price,
        'max_delivery_price': max_delivery_price,
        'machine_wash_count': machineWashCount,
        'machine_dry_count': machineDryCount,
        'detergent_price': detergentprice,
      };
}