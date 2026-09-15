import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/widgets/main_shell_customer.dart';

class CustomerOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const CustomerOrderDetailScreen({super.key, required this.orderId});
  @override
  State<CustomerOrderDetailScreen> createState() =>
      _CustomerOrderDetailScreenState();
}

class _CustomerOrderDetailScreenState extends State<CustomerOrderDetailScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _address;
  Map<String, dynamic>? _riderPickup;
  Map<String, dynamic>? _staff;
  Map<String, dynamic>? _riderDelivery;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _streamSubscription;
  bool _loading = true;
  bool _cancelling = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _listenOrder();
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _resolveReference(dynamic value) async {
    if (value is! DocumentReference) {
      return null;
    }
    final snap = await value.get();
    if (!snap.exists) {
      return null;
    }
    final data = snap.data();
    if (data is Map<String, dynamic>) {
      return data;
    }
    return null;
  }

  Future<void> _listenOrder() async {
    await _streamSubscription?.cancel();
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    _streamSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (snap) async {
            if (!snap.exists) {
              if (!mounted) return;
              setState(() {
                _error = 'ไม่พบข้อมูลออเดอร์';
                _loading = false;
              });
              return;
            }
            final data = snap.data();
            if (data == null) {
              if (!mounted) return;
              setState(() {
                _error = 'ไม่พบข้อมูลออเดอร์';
                _loading = false;
              });
              return;
            }
            try {
              final result = await Future.wait([
                _resolveReference(data['customer_id']),
                _resolveReference(data['address_id']),
                _resolveReference(data['rider_pickup_id']),
                _resolveReference(data['staff_id']),
                _resolveReference(data['rider_delivery_id']),
              ]);
              if (!mounted) return;
              setState(() {
                _order = data;
                _customer = result[0];
                _address = result[1];
                _riderPickup = result[2];
                _staff = result[3];
                _riderDelivery = result[4];
                _loading = false;
                _error = null;
              });
            } catch (e) {
              log('resolve order references error: $e');
              if (!mounted) return;
              setState(() {
                _order = data;
                _loading = false;
              });
            }
          },
          onError: (e) {
            log('listen order error: $e');
            if (!mounted) return;
            setState(() {
              _error = 'เกิดข้อผิดพลาดในการโหลดข้อมูล';
              _loading = false;
            });
          },
        );
  }

  String _fmt(dynamic raw) {
    DateTime? dt;
    if (raw is Timestamp) {
      dt = raw.toDate();
    }
    if (raw is String) {
      dt = DateTime.tryParse(raw);
    }
    if (dt == null) {
      return '-';
    }
    return DateFormat('d MMM yyyy  เวลา HH:mm น.', 'th').format(dt);
  }

  String _shortOrderId(String orderId) {
    final id = orderId.toUpperCase();
    if (id.length <= 8) {
      return id;
    }
    return id.substring(0, 8);
  }

  String _statusLabel(String status) {
    return {
          'pending_confirmation': 'รอยืนยันคำสั่งซื้อ',
          'waiting_payment': 'รอชำระเงิน',
          'payment_completed': 'ชำระเงินแล้ว',
          'waiting_pickup': 'รอรับผ้า',
          'pickup_in_progress': 'กำลังไปรับผ้า',
          'pickup_completed': 'รับผ้าเรียบร้อยกำลังไปที่ร้าน',
          'arrived_at_shop': 'มาถึงร้านแล้ว',
          'waiting_wash': 'รอซัก',
          'washing': 'กำลังซักผ้า',
          'waiting_dry': 'รออบผ้า',
          'drying': 'กำลังอบผ้า',
          'waiting_delivery': 'รอส่งผ้า',
          'delivery_heading_to_shop': 'กำลังไปรับผ้าที่ร้าน',
          'delivery_pickup_completed': 'รับผ้าที่ร้านแล้ว',
          'delivery_in_progress': 'กำลังจัดส่ง',
          'completed': 'เสร็จสิ้น',
          'cancelled': 'ยกเลิก',
        }[status] ??
        status;
  }

  IconData _statusIcon(String status) {
    return {
          'pending_confirmation': Icons.hourglass_empty_rounded,
          'waiting_payment': Icons.payment_rounded,
          'payment_completed': Icons.check_circle_rounded,
          'waiting_pickup': Icons.access_time_rounded,
          'pickup_in_progress': Icons.two_wheeler_rounded,
          'pickup_completed': Icons.task_alt_rounded,
          'arrived_at_shop': Icons.store_rounded,
          'waiting_wash': Icons.hourglass_top_rounded,
          'washing': Icons.local_laundry_service_rounded,
          'waiting_dry': Icons.hourglass_bottom_rounded,
          'drying': Icons.dry_cleaning_rounded,
          'waiting_delivery': Icons.inventory_2_rounded,
          'delivery_heading_to_shop': Icons.store_rounded,
          'delivery_pickup_completed': Icons.checkroom_rounded,
          'delivery_in_progress': Icons.two_wheeler_rounded,
          'completed': Icons.check_circle_rounded,
          'cancelled': Icons.cancel_rounded,
        }[status] ??
        Icons.circle;
  }

  Color _statusMainColor(String status) {
    if (status == 'cancelled') {
      return Colors.red;
    }
    if (status == 'completed') {
      return Colors.green;
    }
    return const Color(0xFF29ABE2);
  }

  Widget _buildStatusCard(String status) {
    final mainColor = _statusMainColor(status);
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
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: mainColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.timeline_rounded, size: 15, color: mainColor),
              ),
              const SizedBox(width: 8),
              const Text(
                'สถานะออเดอร์',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: mainColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: mainColor, width: 2),
                  ),
                  child: Icon(_statusIcon(status), size: 20, color: mainColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'สถานะปัจจุบัน',
                        style: TextStyle(
                          fontSize: 11,
                          color: mainColor.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _statusLabel(status),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: mainColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ตอนนี้',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackbar({
    required String title,
    required String message,
    required Color color,
    required IconData icon,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: color,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
      icon: Icon(icon, color: Colors.white),
    );
  }

  Future<void> _confirmCancel() async {
    if (_cancelling) {
      return;
    }
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'ยืนยันการยกเลิก',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'คุณต้องการยกเลิกออเดอร์นี้หรือไม่?\n\n'
          'สามารถยกเลิกได้เมื่อร้านค้ายังไม่ยืนยันออเดอร์เกิน 5 นาที',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('ไม่', style: TextStyle(color: Colors.black54)),
          ),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text(
              'ยืนยันยกเลิก',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _cancelOrder();
    }
  }

  Future<void> _cancelOrder() async {
    if (_cancelling) {
      return;
    }
    final customerRef = _order?['customer_id'];
    if (customerRef is! DocumentReference) {
      _showSnackbar(
        title: 'ไม่สามารถยกเลิกได้',
        message: 'ไม่พบข้อมูลลูกค้า',
        color: Colors.red,
        icon: Icons.error_rounded,
      );
      return;
    }
    setState(() {
      _cancelling = true;
    });
    try {
      final config = await Configuration.getConfig();
      final baseUrl = config['apiEndpoint']?.toString() ?? '';
      if (baseUrl.isEmpty) {
        throw Exception('ไม่พบ API endpoint');
      }
      final uri = Uri.parse('$baseUrl/order/cancel/${widget.orderId}');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'customerId': customerRef.id}),
      );
      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          body = decoded;
        }
      } catch (_) {}
      if (!mounted) return;
      final message = body['message']?.toString();
      if (res.statusCode == 200 && body['ok'] == true) {
        setState(() {
          _order?['status'] = 'cancelled';
        });
        _showSnackbar(
          title: 'ยกเลิกออเดอร์สำเร็จ',
          message: message ?? 'ยกเลิกออเดอร์สำเร็จ',
          color: const Color(0xFF22C55E),
          icon: Icons.check_circle_rounded,
        );
         await Future.delayed(const Duration(seconds: 1));
  if (mounted) {
    Get.offAll(() => const MainShellCustomer(initialIndex: 1));
  }
      } else {
        _showSnackbar(
          title: 'ยังไม่สามารถยกเลิกได้',
          message: message ?? 'ไม่สามารถยกเลิกออเดอร์ได้',
          color: const Color(0xFFF59E0B),
          icon: Icons.info_rounded,
        );
      }
    } catch (e) {
      log('cancel order error: $e');
      if (!mounted) return;
      _showSnackbar(
        title: 'เกิดข้อผิดพลาด',
        message: 'เกิดข้อผิดพลาดในการยกเลิกออเดอร์',
        color: const Color(0xFFEF4444),
        icon: Icons.error_rounded,
      );
      
    } finally {
      if (mounted) {
        setState(() {
          _cancelling = false;
        });
      }
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
          onPressed: Get.back,
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF29ABE2)),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _listenOrder,
                    child: const Text('ลองใหม่'),
                  ),
                ],
              ),
            )
          : _order == null
          ? const Center(child: Text('ไม่พบข้อมูลออเดอร์'))
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final o = _order!;
    final orderId = o['order_id']?.toString() ?? widget.orderId;
    final status = o['status']?.toString() ?? '';
    final price = (o['service_price'] as num?)?.toDouble() ?? 0;
    final delivery = (o['delivery_price'] as num?)?.toDouble() ?? 0;
    final detergentPrice = (o['detergent_price'] as num?)?.toDouble() ?? 0;
    final detergentOption = o['detergent_option']?.toString();
    final totalPrice = price + delivery + detergentPrice;
    const serviceMap = {
      'wash_dry': 'ซักและอบ',
      'wash': 'ซักอย่างเดียว',
      'dry': 'อบอย่างเดียว',
    };
    const detergentMap = {
      'no_detergent': 'ใช้น้ำยาซักผ้าของร้าน',
      'detergent': 'ใช้น้ำยาซักผ้าของตัวเอง',
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${_shortOrderId(orderId)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 26,
                    letterSpacing: 1.5,
                  ),
                  overflow: TextOverflow.ellipsis,
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
                    Flexible(
                      child: Text(
                        _fmt(o['order_datetime']),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (status.isNotEmpty) _buildStatusCard(status),
          if (status.isNotEmpty) const SizedBox(height: 12),
          if (_customer != null || _address != null) ...[
            _card(
              Icons.person_rounded,
              'ข้อมูลลูกค้า',
              Column(
                children: [
                  if (_customer != null) ...[
                    _row('ชื่อ', _customer!['fullname']?.toString() ?? '-'),
                    _row('เบอร์โทร', _customer!['phone']?.toString() ?? '-'),
                  ],
                  if (_address != null)
                    _row(
                      'ที่อยู่',
                      _address!['address_text']?.toString() ?? '-',
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _card(
            Icons.local_laundry_service_rounded,
            'รายละเอียดบริการ',
            Column(
              children: [
                _row(
                  'รูปแบบบริการ',
                  serviceMap[o['service_type']?.toString()] ?? '-',
                ),
                _row(
                  'น้ำหนักผ้า',
                  o['wash_dry_weight'] != null
                      ? '${o['wash_dry_weight']} กิโลกรัม'
                      : '-',
                  valueColor: const Color(0xFF29ABE2),
                ),
                if (detergentOption != null)
                  _row(
                    'น้ำยาซัก',
                    detergentMap[detergentOption] ?? detergentOption,
                  ),
                if ((o['note'] as String?)?.isNotEmpty == true)
                  _row('หมายเหตุ', o['note'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _card(
            Icons.receipt_long_rounded,
            'รายละเอียดราคา',
            Column(
              children: [
                _row('ค่าซัก', '${price.toInt()} ฿'),
                _row('ค่าจัดส่ง', '${delivery.toInt()} ฿'),
                if (detergentOption == 'no_detergent')
                  _row('ค่าน้ำยาซัก', '${detergentPrice.toInt()} ฿')
                else
                  _row('น้ำยาซัก', 'ใช้น้ำยาซักตัวเอง'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ราคารวมทั้งหมด',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${totalPrice.toInt()} ฿',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Color(0xFF29ABE2),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_riderPickup != null ||
              _staff != null ||
              _riderDelivery != null) ...[
            const SizedBox(height: 12),
            _card(
              Icons.people_rounded,
              'ผู้รับผิดชอบ',
              Column(
                children: [
                  if (_riderPickup != null)
                    _person(
                      Icons.directions_bike_rounded,
                      'ไรเดอร์รับผ้า',
                      _riderPickup!,
                    ),
                  if (_staff != null) ...[
                    if (_riderPickup != null)
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    _person(
                      Icons.local_laundry_service_rounded,
                      'พนักงานซัก',
                      _staff!,
                    ),
                  ],
                  if (_riderDelivery != null) ...[
                    if (_riderPickup != null || _staff != null)
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    _person(
                      Icons.delivery_dining_rounded,
                      'ไรเดอร์ส่งผ้า',
                      _riderDelivery!,
                    ),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          _card(
            Icons.photo_library_rounded,
            'รูปภาพจากร้านค้า',
            Row(
              children: [
                _imgBox(o['before_wash_image'] as String?, 'ก่อนซัก'),
                const SizedBox(width: 12),
                _imgBox(o['after_wash_image'] as String?, 'หลังซัก'),
              ],
            ),
          ),
          if (status == 'pending_confirmation') ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _cancelling ? null : _confirmCancel,
                icon: _cancelling
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      )
                    : const Icon(Icons.cancel_outlined, size: 17),
                label: Text(
                  _cancelling ? 'กำลังยกเลิก...' : 'ยกเลิกออเดอร์',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String title, Widget child) {
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                  overflow: TextOverflow.ellipsis,
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

  Widget _row(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(width: 16),
          Flexible(
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

  String _vehicleText(String value) {

    const vehicleMap = {
      'motorcycle': 'มอเตอร์ไซค์',
      'car': 'รถยนต์',
    };

    final normalized = value.trim().toLowerCase();
    return vehicleMap[normalized] ?? value;
  }

  Widget _person(IconData icon, String role, Map<String, dynamic> data) {
    final profileImage = data['profile_image']?.toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: const Color(0xFFE3F4FC),
          backgroundImage: profileImage != null && profileImage.isNotEmpty
              ? NetworkImage(profileImage)
              : null,
          child: profileImage == null || profileImage.isEmpty
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
                data['fullname']?.toString() ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF1A1A2E),
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _infoChip(
                    Icons.phone_rounded,
                    data['phone']?.toString() ?? '-',
                  ),
                  if (data['license_plate'] != null)
                    _infoChip(
                      Icons.confirmation_number_outlined,
                      'ทะเบียนรถ ${data['license_plate']}',
                    ),
                  if (data['vehicle_type'] != null)
                    _infoChip(
                      Icons.directions_car_rounded,
                      _vehicleText(data['vehicle_type'].toString()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 140),
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _imgBox(String? url, String label) {
    final hasImage = url != null && url.isNotEmpty;
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: hasImage
                ? () {
                    showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url, fit: BoxFit.contain),
                        ),
                      ),
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
                          image: NetworkImage(url),
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
}
