import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/staff/res_order_detail_staff.dart';


class StaffOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const StaffOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<StaffOrderDetailScreen> createState() => _StaffOrderDetailScreenState();
}

class _StaffOrderDetailScreenState extends State<StaffOrderDetailScreen> {
  String url = '';
  bool isLoading = true;
  String? error;

  OrderDetailResponse? orderDetailResponse;
  OrderDetailData? order;

  @override
  void initState() {
    super.initState();
    loadConfigAndFetch();
  }

  Future<void> loadConfigAndFetch() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';

      if (url.isEmpty) {
        setState(() {
          error = 'ไม่พบ apiEndpoint';
          isLoading = false;
        });
        return;
      }

      await fetchOrderDetail();
    } catch (e) {
      setState(() {
        error = 'โหลด config ไม่สำเร็จ: $e';
        isLoading = false;
      });
    }
  }

  Future<void> fetchOrderDetail() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final uri = Uri.parse('$url/order/staff/detail/${widget.orderId}');
      final response = await http.get(uri);

      final parsed = orderDetailResponseFromJson(response.body);
      log('statusCode = ${response.statusCode}');
      log('body = ${response.body}');

      if (response.statusCode != 200 || parsed.ok != true) {
        setState(() {
          error = parsed.message ?? 'เกิดข้อผิดพลาด';
          isLoading = false;
        });
        return;
      }

      setState(() {
        orderDetailResponse = parsed;
        order = parsed.data;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = 'ดึงข้อมูลไม่สำเร็จ: $e';
        isLoading = false;
      });
    }
  }

  String formatDate(dynamic value) {
    if (value == null) return '-';

    if (value is DateTime) {
      return DateFormat('d MMM yyyy เวลา HH:mm น.', 'th').format(value);
    }

    try {
      final dt = DateTime.parse(value.toString());
      return DateFormat('d MMM yyyy เวลา HH:mm น.', 'th').format(dt);
    } catch (_) {
      return value.toString();
    }
  }

  String formatServiceType(String? serviceType) {
    if (serviceType == 'wash_dry') return 'ซักและอบ';
    if (serviceType == 'wash') return 'ซักอย่างเดียว';
    if (serviceType == 'dry') return 'อบอย่างเดียว';
    return '-';
  }

  String formatDetergentOption(String? detergentOption) {
    if (detergentOption == 'detergent') return 'ใช้น้ำยาซักผ้าของร้าน';
    if (detergentOption == 'no_detergent') return 'ไม่ใช้น้ำยาซัก';
    return '-';
  }

  Widget buildCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF29ABE2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF29ABE2)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildImageBox(String? imageUrl, String label) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: hasImage
                ? () {
                    showDialog(
                      context: context,
                      builder: (_) {
                        return Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    );
                  }
                : null,
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  image: hasImage
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImage
                    ? Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            color: Colors.grey.shade400,
                            size: 30,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'ยังไม่มีรูป',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildHeaderCard(OrderDetailData o) {
    final displayId = (o.orderId.isNotEmpty ? o.orderId : widget.orderId);
    final shortId = displayId.length > 8
        ? displayId.substring(0, 8).toUpperCase()
        : displayId.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF29ABE2).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'หมายเลขออเดอร์',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '#$shortId',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 26,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                formatDate(o.orderDatetime),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildCustomerSection(OrderDetailData o) {
    return buildCard(
      icon: Icons.person_rounded,
      title: 'ข้อมูลลูกค้า',
      child: Column(
        children: [
          buildRow('ชื่อ', o.customer?.fullname ?? '-'),
          buildRow('เบอร์โทร', o.customer?.phone ?? '-'),
          buildRow('ที่อยู่', o.address?.addressText ?? '-'),
        ],
      ),
    );
  }

  Widget buildServiceSection(OrderDetailData o) {
    return buildCard(
      icon: Icons.local_laundry_service_rounded,
      title: 'รายละเอียดบริการ',
      child: Column(
        children: [
          buildRow('รูปแบบบริการ', formatServiceType(o.serviceType)),
          buildRow(
            'น้ำหนักผ้า',
            o.washDryWeight != null ? '${o.washDryWeight} กิโลกรัม' : '-',
            valueColor: const Color(0xFF29ABE2),
          ),
          buildRow(
            'น้ำยาซัก',
            formatDetergentOption(o.detergentOption),
          ),
          buildRow('หมายเหตุ', o.note ?? '-'),
        ],
      ),
    );
  }

  Widget buildImageSection(OrderDetailData o) {
    return buildCard(
      icon: Icons.photo_library_rounded,
      title: 'รูปภาพจากร้านค้า',
      child: Row(
        children: [
          buildImageBox(o.beforeWashImage, 'ก่อนซัก'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = order;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'รายละเอียดออเดอร์',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF29ABE2),
              ),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: fetchOrderDetail,
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : o == null
                  ? const Center(
                      child: Text('ไม่พบข้อมูลออเดอร์'),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          buildHeaderCard(o),
                          const SizedBox(height: 12),

                          buildCustomerSection(o),
                          const SizedBox(height: 12),

                          buildServiceSection(o),
                          const SizedBox(height: 12),

                          buildImageSection(o),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}