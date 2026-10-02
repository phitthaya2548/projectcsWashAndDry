import 'dart:convert';

UpdateMachineRequest updateMachineRequestFromJson(String str) =>
    UpdateMachineRequest.fromJson(json.decode(str));

String updateMachineRequestToJson(UpdateMachineRequest data) =>
    json.encode(data.toJson());

class UpdateMachineRequest {
  final String name;
  final String type;
  final int capacity;
  final double price;
  final int workMinutes;
  final String status;

  UpdateMachineRequest({
    required this.name,
    required this.type,
    required this.capacity,
    required this.price,
    required this.workMinutes,
    required this.status,
  });

  factory UpdateMachineRequest.fromJson(Map<String, dynamic> json) {
    return UpdateMachineRequest(
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      capacity: json['capacity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      workMinutes: json['work_minutes'] ?? 0,
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'capacity': capacity,
      'price': price,
      'work_minutes': workMinutes,
      'status': status,
    };
  }
}