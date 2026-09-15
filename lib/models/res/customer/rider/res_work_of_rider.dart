class WorkOfRider {
  final String id;
  final String? orderNumber;
  final String status;
  final String? serviceType;
  final double? distanceKm;
  final double? addressLat;
  final double? addressLng;
  final String? note;
  final String? beforeWashImage;
  final String? afterWashImage;
  final String? riderPickupId;
  final String? riderDeliveryId;
  final DateTime? orderDatetime;
  final String? address;
  final CustomerOfRider? customer;

  WorkOfRider({
    required this.id,
    this.orderNumber,
    required this.status,
    this.serviceType,
    this.distanceKm,
    this.addressLat,
    this.addressLng,
    this.note,
    this.beforeWashImage,
    this.afterWashImage,
    this.riderPickupId,
    this.riderDeliveryId,
    this.orderDatetime,
    this.address,
    this.customer,
  });

  factory WorkOfRider.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkOfRider(
      id: json['id'] ?? '',
      orderNumber: json['order_number'],
      status: json['status'] ?? '',
      serviceType: json['service_type'],
      distanceKm:
          (json['distance_km'] as num?)?.toDouble(),
      addressLat:
          (json['address_lat'] as num?)?.toDouble(),
      addressLng:
          (json['address_lng'] as num?)?.toDouble(),
      note: json['note'],
      beforeWashImage:
          json['before_wash_image'],
      afterWashImage:
          json['after_wash_image'],
      riderPickupId:
          json['rider_pickup_id'],
      riderDeliveryId:
          json['rider_delivery_id'],
      orderDatetime:
          json['order_datetime'] != null
              ? DateTime.tryParse(
                  json['order_datetime'].toString(),
                )
              : null,
      address: json['address'],
      customer:
          json['customer'] != null
              ? CustomerOfRider.fromJson(
                  json['customer']
                      as Map<String, dynamic>,
                )
              : null,
    );
  }

  WorkOfRider copyWith({
    double? distanceKm,
  }) {
    return WorkOfRider(
      id: id,
      orderNumber: orderNumber,
      status: status,
      serviceType: serviceType,
      distanceKm:
          distanceKm ?? this.distanceKm,
      addressLat: addressLat,
      addressLng: addressLng,
      note: note,
      beforeWashImage: beforeWashImage,
      afterWashImage: afterWashImage,
      riderPickupId: riderPickupId,
      riderDeliveryId: riderDeliveryId,
      orderDatetime: orderDatetime,
      address: address,
      customer: customer,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': status,
      'service_type': serviceType,
      'distance_km': distanceKm,
      'address_lat': addressLat,
      'address_lng': addressLng,
      'note': note,
      'before_wash_image': beforeWashImage,
      'after_wash_image': afterWashImage,
      'rider_pickup_id': riderPickupId,
      'rider_delivery_id': riderDeliveryId,
      'order_datetime':
          orderDatetime?.toIso8601String(),
      'address': address,
      'customer': customer?.toJson(),
    };
  }
}

class CustomerOfRider {
  final String id;
  final String name;
  final String phone;
  final String? profileImage;

  CustomerOfRider({
    required this.id,
    required this.name,
    required this.phone,
    this.profileImage,
  });

  factory CustomerOfRider.fromJson(
    Map<String, dynamic> json,
  ) {
    return CustomerOfRider(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      profileImage:
          json['profile_image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'profile_image': profileImage,
    };
  }
}