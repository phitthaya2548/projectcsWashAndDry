class StaffInfo {
  final String? staffId;
  final String fullname;
  final String phone;
  final String? profileImage;
  final String? username;

  const StaffInfo({
    required this.staffId,
    required this.fullname,
    required this.phone,
    required this.profileImage,
    required this.username,
  });

  factory StaffInfo.fromJson(Map<String, dynamic> j) => StaffInfo(
    staffId: j['staff_id'] as String?,
    fullname: j['fullname'] as String? ?? '-',
    phone: j['phone'] as String? ?? '-',
    profileImage: j['profile_image'] as String?,
    username: j['username'] as String?,
  );
}

class RiderInfo {
  final String? riderId;
  final String fullname;
  final String phone;
  final String? profileImage;
  final String? vehicleType;
  final String? licensePlate;

  const RiderInfo({
    required this.riderId,
    required this.fullname,
    required this.phone,
    required this.profileImage,
    required this.vehicleType,
    required this.licensePlate,
  });

  factory RiderInfo.fromJson(Map<String, dynamic> j) => RiderInfo(
    riderId: j['rider_id'] as String?,
    fullname: j['fullname'] as String? ?? '-',
    phone: j['phone'] as String? ?? '-',
    profileImage: j['profile_image'] as String?,
    vehicleType: j['vehicle_type'] as String?,
    licensePlate: j['license_plate'] as String?,
  );
}

class StoreCompletedOrder {
  final String orderId;
  final String status;
  final String serviceType;
  final String? detergentOption;
  final num servicePrice;
  final num deliveryPrice;
  final num totalAmount;
  final num? washDryWeight;
  final String? note;
  final String? beforeWashImage;
  final String? afterWashImage;
  final Map<String, dynamic>? orderDatetime;
  final String? storeId;
  final String? addressId;
  final String? machineWasherId;
  final String? machineDryerId;
  final num detergentPrice;
  final String customerFullname;
  final String customerPhone;
  final String addressFull;
  final RiderInfo? riderPickup;
  final RiderInfo? riderDelivery;
  final StaffInfo? staff;

  const StoreCompletedOrder({
    required this.orderId,
    required this.status,
    required this.serviceType,
    required this.detergentOption,
    required this.servicePrice,
    required this.deliveryPrice,
    required this.totalAmount,
    required this.washDryWeight,
    required this.note,
    required this.beforeWashImage,
    required this.detergentPrice,
    required this.afterWashImage,
    required this.orderDatetime,
    required this.storeId,
    required this.addressId,
    required this.machineWasherId,
    required this.machineDryerId,
    required this.customerFullname,
    required this.customerPhone,
    required this.addressFull,
    required this.riderPickup,
    required this.riderDelivery,
    required this.staff,
  });

  factory StoreCompletedOrder.fromJson(Map<String, dynamic> j) =>
      StoreCompletedOrder(
        orderId: j['order_id'] as String? ?? '',
        status: j['status'] as String? ?? '',
        serviceType: j['service_type'] as String? ?? '',
        detergentOption: j['detergent_option'] as String?,
        servicePrice: j['service_price'] as num? ?? 0,
        deliveryPrice: j['delivery_price'] as num? ?? 0,
        totalAmount: j['total_amount'] as num? ?? 0,
        washDryWeight: j['wash_dry_weight'] as num?,
        note: j['note'] as String?,

        beforeWashImage: j['before_wash_image'] as String?,
        detergentPrice: j['detergent_price'] as num? ?? 0,
        afterWashImage: j['after_wash_image'] as String?,
        orderDatetime: j['order_datetime'] as Map<String, dynamic>?,
        storeId: j['store_id'] as String?,
        addressId: j['address_id'] as String?,
        machineWasherId: j['machine_washer_id'] as String?,
        machineDryerId: j['machine_dryer_id'] as String?,
        customerFullname: j['customer_fullname'] as String? ?? '-',
        customerPhone: j['customer_phone'] as String? ?? '-',
        addressFull: j['address_full'] as String? ?? '-',
        riderPickup: j['rider_pickup'] != null
            ? RiderInfo.fromJson(j['rider_pickup'] as Map<String, dynamic>)
            : null,
        riderDelivery: j['rider_delivery'] != null
            ? RiderInfo.fromJson(j['rider_delivery'] as Map<String, dynamic>)
            : null,
        staff: j['staff'] != null
            ? StaffInfo.fromJson(j['staff'] as Map<String, dynamic>)
            : null,
      );
}