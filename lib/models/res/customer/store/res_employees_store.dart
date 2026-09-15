class EmployeeStoreResponse {
  final bool ok;
  final int total;
  final List<Employee> data;

  EmployeeStoreResponse({
    required this.ok,
    required this.total,
    required this.data,
  });

  factory EmployeeStoreResponse.fromJson(Map<String, dynamic> json) {
    return EmployeeStoreResponse(
      ok: json['ok'] ?? false,
      total: json['total'] ?? 0,
      data: (json['data'] as List<dynamic>? ?? [])
          .map((e) => Employee.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Employee {
  final String type;
  final String id;
  final String fullName;
  final String username;
  final String email;
  final String phone;
  final String status;
  final String? profileImage;

  final String? vehicleType;
  final String? licensePlate;
  final double? latitude;
  final double? longitude;

  Employee({
    required this.type,
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.phone,
    required this.status,
    this.profileImage,
    this.vehicleType,
    this.licensePlate,
    this.latitude,
    this.longitude,
  });

  bool get isRider => type == 'rider';
  bool get isStaff => type == 'staff';

  factory Employee.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    return Employee(
      type: type,
      id: (type == 'rider' ? json['rider_id'] : json['staff_id'])?.toString() ?? '',
      fullName: json['fullname']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      profileImage: json['profile_image']?.toString(),
      vehicleType: json['vehicle_type']?.toString(),
      licensePlate: json['license_plate']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}