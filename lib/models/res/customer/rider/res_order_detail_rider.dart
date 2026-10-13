import 'dart:convert';

OrderDetailResponse orderDetailResponseFromJson(String str) =>
    OrderDetailResponse.fromJson(json.decode(str));

String orderDetailResponseToJson(OrderDetailResponse data) =>
    json.encode(data.toJson());

class OrderDetailResponse {
  bool? ok;
  OrderDetailData? data;
  String? message;

  OrderDetailResponse({
    this.ok,
    this.data,
    this.message,
  });

  factory OrderDetailResponse.fromJson(Map<String, dynamic> json) =>
      OrderDetailResponse(
        ok: json["ok"],
        data: json["data"] == null
            ? null
            : OrderDetailData.fromJson(json["data"]),
        message: json["message"],
      );

  Map<String, dynamic> toJson() => {
        "ok": ok,
        "data": data?.toJson(),
        "message": message,
      };
}

class OrderDetailData {
  String? orderId;
  String? serviceType;
  num? washDryWeight;
  String? detergentOption;
  String? note;
  DateTime? orderDatetime;
  double? distanceKm;
  FromLocationModel? fromLocation;
  CustomerModel? customer;
  RiderModel? riderPickup;
  RiderModel? riderDelivery;
  AddressModel? address;

  OrderDetailData({
    this.orderId,
    this.serviceType,
    this.washDryWeight,
    this.detergentOption,
    this.note,
    this.orderDatetime,
    this.distanceKm,
    this.fromLocation,
    this.customer,
    this.riderPickup,
    this.riderDelivery,
    this.address,
  });

  factory OrderDetailData.fromJson(Map<String, dynamic> json) =>
      OrderDetailData(
        orderId: json["order_id"],
        serviceType: json["service_type"],
        washDryWeight: json["wash_dry_weight"],
        detergentOption: json["detergent_option"],
        note: json["note"],
        orderDatetime: parseFirestoreDateTime(json["order_datetime"]),
        distanceKm: (json["distance_km"] as num?)?.toDouble(),
        fromLocation: json["from_location"] == null
            ? null
            : FromLocationModel.fromJson(json["from_location"]),
        customer: json["customer"] == null
            ? null
            : CustomerModel.fromJson(json["customer"]),
        riderPickup: json["rider_pickup"] == null
            ? null
            : RiderModel.fromJson(json["rider_pickup"]),
        riderDelivery: json["rider_delivery"] == null
            ? null
            : RiderModel.fromJson(json["rider_delivery"]),
        address: json["address"] == null
            ? null
            : AddressModel.fromJson(json["address"]),
      );

  Map<String, dynamic> toJson() => {
        "order_id": orderId,
        "service_type": serviceType,
        "wash_dry_weight": washDryWeight,
        "detergent_option": detergentOption,
        "note": note,
        "order_datetime": orderDatetime?.toIso8601String(),
        "distance_km": distanceKm,
        "from_location": fromLocation?.toJson(),
        "customer": customer?.toJson(),
        "rider_pickup": riderPickup?.toJson(),
        "rider_delivery": riderDelivery?.toJson(),
        "address": address?.toJson(),
      };
}

class CustomerModel {
  String? fullname;
  String? phone;
  String? profileImage;

  CustomerModel({
    this.fullname,
    this.phone,
    this.profileImage,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        fullname: json["fullname"],
        phone: json["phone"],
        profileImage: json["profile_image"],
      );

  Map<String, dynamic> toJson() => {
        "fullname": fullname,
        "phone": phone,
        "profile_image": profileImage,
      };
}

class RiderModel {
  String? id;
  String? fullname;
  String? phone;
  String? profileImage;
  double? latitude;
  double? longitude;

  RiderModel({
    this.id,
    this.fullname,
    this.phone,
    this.profileImage,
    this.latitude,
    this.longitude,
  });

  factory RiderModel.fromJson(Map<String, dynamic> json) => RiderModel(
        id: json["id"],
        fullname: json["fullname"],
        phone: json["phone"],
        profileImage: json["profile_image"],
        latitude: (json["latitude"] as num?)?.toDouble(),
        longitude: (json["longitude"] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "fullname": fullname,
        "phone": phone,
        "profile_image": profileImage,
        "latitude": latitude,
        "longitude": longitude,
      };
}

/// จุดเริ่มต้นที่ backend ใช้คำนวณระยะทาง (source = "query" หรือ "rider")
class FromLocationModel {
  double? latitude;
  double? longitude;
  String? source;

  FromLocationModel({
    this.latitude,
    this.longitude,
    this.source,
  });

  factory FromLocationModel.fromJson(Map<String, dynamic> json) =>
      FromLocationModel(
        latitude: (json["latitude"] as num?)?.toDouble(),
        longitude: (json["longitude"] as num?)?.toDouble(),
        source: json["source"],
      );

  Map<String, dynamic> toJson() => {
        "latitude": latitude,
        "longitude": longitude,
        "source": source,
      };
}

class AddressModel {
  String? addressText;
  double? latitude;
  double? longitude;

  AddressModel({
    this.addressText,
    this.latitude,
    this.longitude,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) => AddressModel(
        addressText: json["address_text"],
        latitude: (json["latitude"] as num?)?.toDouble(),
        longitude: (json["longitude"] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "address_text": addressText,
        "latitude": latitude,
        "longitude": longitude,
      };
}

DateTime? parseFirestoreDateTime(dynamic json) {
  if (json == null) {
    return null;
  }

  if (json is String) {
    final parsed = DateTime.tryParse(json);
    return parsed?.toLocal();
  }

  if (json is Map<String, dynamic>) {
    final seconds = json["_seconds"];
    if (seconds != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (seconds as num).toInt() * 1000,
      ).toLocal();
    }
  }

  return null;
}