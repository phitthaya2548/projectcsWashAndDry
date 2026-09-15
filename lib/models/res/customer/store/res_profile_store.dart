class StoreData {
  final String storeId;
  final String username;
  final String storeName;
  final String email;
  final String phone;
  final String facebook;
  final String lineId;
  final String address;
  final String openingHours;
  final String closedHours;
  final double serviceRadius;
  final double latitude;
  final double longitude;
  final String status;
  final String profileImage;
  final double walletBalance;
  final double deliveryMin;
  final double deliveryMax;
  final double detergentPrice;
  final int machineWashCount;
  final int machineDryCount;

  StoreData({
    required this.storeId,
    required this.username,
    required this.storeName,
    required this.email,
    required this.phone,
    required this.facebook,
    required this.lineId,
    required this.address,
    required this.openingHours,
    required this.closedHours,
    required this.serviceRadius,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.profileImage,
    required this.walletBalance,
    this.deliveryMin = 0,
    this.deliveryMax = 0,
    this.detergentPrice = 0,
    this.machineWashCount = 0,
    this.machineDryCount = 0,
  });

  factory StoreData.fromJson(Map<String, dynamic> json) {
    double toDouble(dynamic v) {
      if (v == null) return 0.0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0.0;
    }

    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    return StoreData(
      storeId:          json['store_id']?.toString()      ?? '',
      username:         json['username']?.toString()      ?? '',
      storeName:        json['store_name']?.toString()    ?? '',
      email:            json['email']?.toString()         ?? '',
      phone:            json['phone']?.toString()         ?? '',
      facebook:         json['facebook']?.toString()      ?? '',
      lineId:           json['line_id']?.toString()       ?? '',
      address:          json['address']?.toString()       ?? '',
      openingHours:     json['opening_hours']?.toString() ?? '',
      closedHours:      json['closed_hours']?.toString()  ?? '',
      status:           json['status']?.toString()        ?? 'OPEN',
      profileImage:     json['profile_image']?.toString() ?? '',
      serviceRadius:    toDouble(json['service_radius']),
      latitude:         toDouble(json['latitude']),
      longitude:        toDouble(json['longitude']),
      walletBalance:    toDouble(json['wallet_balance']),
      deliveryMin:      toDouble(json['delivery_min']),
      deliveryMax:      toDouble(json['delivery_max']),
      detergentPrice:   toDouble(json['detergent_price']),
      machineWashCount: toInt(json['machine_wash_count']),
      machineDryCount:  toInt(json['machine_dry_count']),
    );
  }

  Map<String, dynamic> toJson() => {
    'store_id':           storeId,
    'username':           username,
    'store_name':         storeName,
    'email':              email,
    'phone':              phone,
    'facebook':           facebook,
    'line_id':            lineId,
    'address':            address,
    'opening_hours':      openingHours,
    'closed_hours':       closedHours,
    'service_radius':     serviceRadius,
    'latitude':           latitude,
    'longitude':          longitude,
    'status':             status,
    'profile_image':      profileImage,
    'wallet_balance':     walletBalance,
    'delivery_min':       deliveryMin,
    'delivery_max':       deliveryMax,
    'detergent_price':    detergentPrice,
    'machine_wash_count': machineWashCount,
    'machine_dry_count':  machineDryCount,
  };

  StoreData copyWith({
    String? storeId,
    String? username,
    String? storeName,
    String? email,
    String? phone,
    String? facebook,
    String? lineId,
    String? address,
    String? openingHours,
    String? closedHours,
    double? serviceRadius,
    double? latitude,
    double? longitude,
    String? status,
    String? profileImage,
    double? walletBalance,
    double? deliveryMin,
    double? deliveryMax,
    double? detergentPrice,
    int? machineWashCount,
    int? machineDryCount,
  }) {
    return StoreData(
      storeId:          storeId          ?? this.storeId,
      username:         username         ?? this.username,
      storeName:        storeName        ?? this.storeName,
      email:            email            ?? this.email,
      phone:            phone            ?? this.phone,
      facebook:         facebook         ?? this.facebook,
      lineId:           lineId           ?? this.lineId,
      address:          address          ?? this.address,
      openingHours:     openingHours     ?? this.openingHours,
      closedHours:      closedHours      ?? this.closedHours,
      serviceRadius:    serviceRadius    ?? this.serviceRadius,
      latitude:         latitude         ?? this.latitude,
      longitude:        longitude        ?? this.longitude,
      status:           status           ?? this.status,
      profileImage:     profileImage     ?? this.profileImage,
      walletBalance:    walletBalance    ?? this.walletBalance,
      deliveryMin:      deliveryMin      ?? this.deliveryMin,
      deliveryMax:      deliveryMax      ?? this.deliveryMax,
      detergentPrice:   detergentPrice   ?? this.detergentPrice,
      machineWashCount: machineWashCount ?? this.machineWashCount,
      machineDryCount:  machineDryCount  ?? this.machineDryCount,
    );
  }
}