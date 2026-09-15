import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_file.dart';
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_order_completed_customer.dart';
import 'package:wash_and_dry/screens/customer/customer_review_screen.dart';

class CustomerCompletedScreen extends StatefulWidget {
  final String orderId;
  const CustomerCompletedScreen({super.key, required this.orderId});

  @override
  State<CustomerCompletedScreen> createState() =>
      _CustomerCompletedScreenState();
}

class _CustomerCompletedScreenState extends State<CustomerCompletedScreen> {
  CompletedOrder? order;
  bool isLoading = true;
  String? error;
  String url = '';

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  void loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {
      setState(() => url = '');
    }
    await fetchCompletedOrder();
  }

  Future<void> fetchCompletedOrder() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final res = await http.get(
        Uri.parse('$url/order/customer/completed/${widget.orderId}'),
        headers: {'Content-Type': 'application/json'},
      );
      if (res.statusCode == 200) {
        setState(() => order = completedOrderFromJson(res.body));
      } else {
        setState(() => error = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})');
      }
    } catch (e) {
      setState(() => error = 'เกิดข้อผิดพลาด: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
            ),
          ),
        ),
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        foregroundColor: Colors.white,
        title: const Text(
          'ใบเสร็จ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF29ABE2)),
            )
          : error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    error!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: fetchCompletedOrder,
                    icon: const Icon(Icons.refresh),
                    label: const Text('ลองใหม่'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF29ABE2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : order == null
          ? const Center(child: Text('ไม่พบข้อมูลออเดอร์'))
          : _buildDetail(order!),
    );
  }

  Widget _buildDetail(CompletedOrder o) {
    final dateStr = o.orderDatetime != null
        ? DateFormat('d MMM yyyy  เวลา HH:mm น.', 'th').format(o.orderDatetime!)
        : '-';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOrderHeader(o, dateStr),
          const SizedBox(height: 12),

          _buildSection(
            icon: Icons.local_laundry_service_rounded,
            title: 'รายละเอียดบริการ',
            child: Column(
              children: [
                _buildRow(
                  'รูปแบบบริการ',
                  o.serviceType == 'wash_dry' ? 'ซักและอบ' : 
                  o.serviceType == 'wash' ? 'ซักอย่างเดียว'  :
                  o.serviceType == 'dry' ? 'ซักอย่างเดียว' : '-'
                ),
                _buildRow(
                  'น้ำหนักผ้า',
                  '${o.washDryWeight} กิโลกรัม',
                  valueColor: const Color(0xFF29ABE2),
                ),
                if (o.detergentOption != null)
                  _buildRow(
                    'น้ำยาซัก',
                    o.detergentOption == 'no_detergent'
                        ? 'ใช้น้ำยาซักผ้าของร้าน'
                        : o.detergentOption == 'detergent'
                            ? 'ใช้น้ำยาซักผ้าตัวเอง'
                            : o.detergentOption ?? '-',
                  ),
                if (o.note != null && o.note!.isNotEmpty)
                  _buildRow('หมายเหตุ', o.note!),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildSection(
            icon: Icons.receipt_long_rounded,
            title: 'รายละเอียดราคา',
            child: Column(
              children: [
                _buildRow('ค่าซัก', '${o.servicePrice.toInt()} ฿'), 
                _buildRow('ค่าจัดส่ง', '${o.deliveryPrice.toInt()} ฿'), 
                if (o.detergentPrice > 0)
                    _buildRow('ค่าน้ำยาซัก', '${o.detergentPrice.toInt()} ฿'),
  
  
                  
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ราคารวมทั้งหมด',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('${o.totalAmount.toInt()} ฿',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF29ABE2),
                        )),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (o.riderPickup != null ||
              o.staff != null ||
              o.riderDelivery != null)
            _buildSection(
              icon: Icons.people_rounded,
              title: 'ผู้รับผิดชอบ',
              child: Column(
                children: [
                  if (o.riderPickup != null)
                    _buildPersonRow(
                      icon: Icons.directions_bike_rounded,
                      role: 'ไรเดอร์รับผ้า',
                      fullname: o.riderPickup?.fullname,
                      phone: o.riderPickup?.phone,
                      vehicleType: o.riderPickup?.vehicleType,
                      imageUrl: o.riderPickup?.profileImage,
                      extra: o.riderPickup?.licensePlate,
                    ),
                  if (o.staff != null) ...[
                    if (o.riderPickup != null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 10),
                        child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ),
                    _buildPersonRow(
                      icon: Icons.local_laundry_service_rounded,
                      role: 'พนักงานซัก',
                      fullname: o.staff!.fullname,
                      phone: o.staff!.phone,
                      imageUrl: o.staff!.profileImage,
                    ),
                  ],
                  if (o.riderDelivery != null) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                    ),
                    _buildPersonRow(
                      icon: Icons.delivery_dining_rounded,
                      role: 'ไรเดอร์ส่งผ้า',
                      fullname: o.riderDelivery!.fullname,
                      phone: o.riderDelivery!.phone,
                      vehicleType: o.riderDelivery?.vehicleType,
                      imageUrl: o.riderDelivery!.profileImage,
                      extra: o.riderDelivery!.licensePlate,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          _buildSection(
            icon: Icons.photo_library_rounded,
            title: 'รูปภาพจากร้านค้า',
            child: Row(
              children: [
                _buildImageBox(o.beforeWashImage, 'ก่อนซัก'),
                const SizedBox(width: 12),
                _buildImageBox(o.afterWashImage, 'หลังซัก'),
              ],
            ),
          ),
          const SizedBox(height: 12),

          _buildReviewSection(o),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildOrderHeader(CompletedOrder o, String dateStr) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
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
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '#${o.orderId.toUpperCase().substring(0, o.orderId.length.clamp(0, 8))}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 26,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 13,
              ),
              const SizedBox(width: 6),
              Text(
                dateStr,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
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

  Widget _buildRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isBold ? Colors.black87 : Colors.black54,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _vehicleText(String value) {
    // Backend ส่งค่าเป็นภาษาอังกฤษ แต่ UI แสดงภาษาไทย
    const vehicleMap = {
      'motorcycle': 'มอเตอร์ไซค์',
      'motorbike': 'มอเตอร์ไซค์',
      'car': 'รถยนต์',

      // รองรับข้อมูลเก่าที่อาจเก็บเป็นภาษาไทย
      'มอเตอร์ไซค์': 'มอเตอร์ไซค์',
      'จักรยานยนต์': 'มอเตอร์ไซค์',
      'รถจักรยานยนต์': 'มอเตอร์ไซค์',
      'รถยนต์': 'รถยนต์',
    };

    final normalized = value.trim().toLowerCase();
    return vehicleMap[normalized] ?? value;
  }

  Widget _buildPersonRow({
    required IconData icon,
    required String role,
    String? fullname,
    String? phone,
    String? imageUrl,
    String? extra,
    String? vehicleType,
  }) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFE3F4FC),
          backgroundImage: imageUrl != null && imageUrl.isNotEmpty
              ? NetworkImage(imageUrl)
              : null,
          child: imageUrl == null || imageUrl.isEmpty
              ? Icon(icon, color: const Color(0xFF29ABE2), size: 22)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF29ABE2),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                fullname ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Icon(Icons.phone_rounded, size: 12, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      phone ?? '-',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
              if (vehicleType != null && vehicleType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions_car_rounded,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _vehicleText(vehicleType),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (extra != null && extra.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined,
                        size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "ทะเบียนรถ " + extra,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _chip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageBox(String? imageUrl, String label) {
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: hasImage
                ? () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(imageUrl!, fit: BoxFit.contain),
                        ),
                      ),
                    )
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
                          image: NetworkImage(imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: !hasImage
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: Colors.grey.shade400, size: 30),
                          const SizedBox(height: 4),
                          Text('ยังไม่มีรูป',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      )
                    : Align(
                        alignment: Alignment.bottomRight,
                        child: Container(
                          margin: const EdgeInsets.all(6),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.zoom_in_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildReviewSection(CompletedOrder o) {
    final reviewed = o.review != null;

    return _buildSection(
      icon: Icons.star_rounded,
      title: reviewed ? 'รีวิวของคุณ' : 'รีวิวร้านค้า',
      child: reviewed
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      i < o.review!.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFFBBF24),
                      size: 22,
                    );
                  }),
                ),
                if (o.review!.comment != null && o.review!.comment!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    o.review!.comment!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final result = await Get.to(
                    () => CustomerReviewScreen(orderId: o.orderId),
                  );
                  if (result == true) fetchCompletedOrder();
                },
                icon: const Icon(Icons.star_rounded),
                label: const Text(
                  'ให้คะแนนร้านค้า',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFBBF24),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
    );
  }
}