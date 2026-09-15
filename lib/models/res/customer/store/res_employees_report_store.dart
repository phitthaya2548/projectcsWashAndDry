class EmployeeReportResponse {
  final bool ok;
  final ReportPeriod? period;
  final int totalOrders;
  final List<StaffReport> staffs;
  final List<RiderReport> riders;

  EmployeeReportResponse({
    required this.ok,
    this.period,
    required this.totalOrders,
    required this.staffs,
    required this.riders,
  });

  factory EmployeeReportResponse.fromJson(
    Map<String, dynamic> json,
  ) {
    return EmployeeReportResponse(
      ok: json['ok'] == true,
      period: json['period'] is Map
          ? ReportPeriod.fromJson(
              Map<String, dynamic>.from(
                json['period'],
              ),
            )
          : null,
      totalOrders: _toInt(json['total_orders']),
      staffs: (json['staffs'] as List? ?? [])
          .map(
            (e) => StaffReport.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
      riders: (json['riders'] as List? ?? [])
          .map(
            (e) => RiderReport.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList(),
    );
  }
}

class ReportPeriod {
  final String type;
  final int? day;
  final int month;
  final int year;

  ReportPeriod({
    required this.type,
    this.day,
    required this.month,
    required this.year,
  });

  factory ReportPeriod.fromJson(
    Map<String, dynamic> json,
  ) {
    return ReportPeriod(
      type: json['type']?.toString() ?? '',
      day: json['day'] == null
          ? null
          : _toInt(json['day']),
      month: _toInt(json['month']),
      year: _toInt(json['year']),
    );
  }
}

class StaffReport {
  final String type;
  final String id;
  final String fullname;
  final String? profileImage;
  final int totalJobs;

  StaffReport({
    required this.type,
    required this.id,
    required this.fullname,
    this.profileImage,
    required this.totalJobs,
  });

  factory StaffReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return StaffReport(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      profileImage:
          json['profile_image']?.toString(),
      totalJobs: _toInt(json['total_jobs']),
    );
  }
}

class RiderReport {
  final String type;
  final String id;
  final String fullname;
  final String? profileImage;
  final int pickupJobs;
  final int deliveryJobs;
  final int totalJobs;

  RiderReport({
    required this.type,
    required this.id,
    required this.fullname,
    this.profileImage,
    required this.pickupJobs,
    required this.deliveryJobs,
    required this.totalJobs,
  });

  factory RiderReport.fromJson(
    Map<String, dynamic> json,
  ) {
    return RiderReport(
      type: json['type']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      fullname: json['fullname']?.toString() ?? '',
      profileImage:
          json['profile_image']?.toString(),
      pickupJobs: _toInt(json['pickup_jobs']),
      deliveryJobs:
          _toInt(json['delivery_jobs']),
      totalJobs: _toInt(json['total_jobs']),
    );
  }
}

int _toInt(dynamic value) {
  if (value == null) return 0;

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(
        value.toString(),
      ) ??
      0;
}