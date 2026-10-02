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
  CustomerModel? customer;
  AddressModel? address;

  OrderDetailData({
    this.orderId,
    this.serviceType,
    this.washDryWeight,
    this.detergentOption,
    this.note,
    this.orderDatetime,
    this.customer,
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
        customer: json["customer"] == null
            ? null
            : CustomerModel.fromJson(json["customer"]),
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
        "customer": customer?.toJson(),
        "address": address?.toJson(),
      };
}

class CustomerModel {
  String? fullname;
  String? phone;

  CustomerModel({
    this.fullname,
    this.phone,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        fullname: json["fullname"],
        phone: json["phone"],
      );

  Map<String, dynamic> toJson() => {
        "fullname": fullname,
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