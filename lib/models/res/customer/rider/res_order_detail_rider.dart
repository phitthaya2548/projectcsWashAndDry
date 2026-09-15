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
  String? customerId;
  String? addressId;
  String? storeId;
  String? serviceType;
  num? washDryWeight;
  num? servicePrice;
  String? detergentOption;
  String? note;
  String? status;
  DateTime? orderDatetime;
  CustomerModel? customer;
  AddressModel? address;

  OrderDetailData({
    this.orderId,
    this.customerId,
    this.addressId,
    this.storeId,
    this.serviceType,
    this.washDryWeight,
    this.servicePrice,
    this.detergentOption,
    this.note,
    this.status,
    this.orderDatetime,
    this.customer,
    this.address,
  });

  factory OrderDetailData.fromJson(Map<String, dynamic> json) =>
      OrderDetailData(
        orderId: json["order_id"],
        customerId: json["customer_id"],
        addressId: json["address_id"],
        storeId: json["store_id"],
        serviceType: json["service_type"],
        washDryWeight: json["wash_dry_weight"],
        servicePrice: json["service_price"],
        detergentOption: json["detergent_option"],
        note: json["note"],
        status: json["status"],
        orderDatetime: parseFirestoreDateTime(json["order_datetime"]),
        customer: json["customer"] == null
            ? null
            : CustomerModel.fromJson(json["customer"]),
        address: json["address"] == null
            ? null
            : AddressModel.fromJson(json["address"]),
      );

  Map<String, dynamic> toJson() => {
        "order_id": orderId,
        "customer_id": customerId,
        "address_id": addressId,
        "store_id": storeId,
        "service_type": serviceType,
        "wash_dry_weight": washDryWeight,
        "service_price": servicePrice,
        "detergent_option": detergentOption,
        "note": note,
        "status": status,
        "order_datetime": orderDatetime?.toIso8601String(),
        "customer": customer?.toJson(),
        "address": address?.toJson(),
      };
}

class CustomerModel {
  String? customerId;
  String? username;
  String? fullname;
  String? profileImage;
  String? phone;

  CustomerModel({
    this.customerId,
    this.username,
    this.fullname,
    this.profileImage,
    this.phone,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        customerId: json["customer_id"],
        username: json["username"],
        fullname: json["fullname"],
        profileImage: json["profile_image"],
        phone: json["phone"],
      );

  Map<String, dynamic> toJson() => {
        "customer_id": customerId,
        "username": username,
        "fullname": fullname,
        "profile_image": profileImage,
        "phone": phone,
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
        latitude: json["latitude"]?.toDouble(),
        longitude: json["longitude"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "address_text": addressText,
        "latitude": latitude,
        "longitude": longitude,
      };
}

/// Parses order_datetime coming back from the API.
///
/// The backend now sends this as an ISO-8601 string (via `.toISOString()`
/// on the server), NOT the old Firestore `{ "_seconds": ... }` map shape.
/// The previous version of this function only handled the map shape, so
/// for a String value it fell through and returned null -- that's why the
/// time wasn't showing up on the order detail screen.
///
/// This still supports the old Firestore map shape too, in case any other
/// endpoint still sends it that way, and always returns the DateTime
/// converted to local time so `DateFormat(...).format(...)` shows the
/// correct Thailand time instead of raw UTC.
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