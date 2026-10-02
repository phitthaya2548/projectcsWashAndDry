import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';

class StoreOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const StoreOrderDetailScreen({super.key, required this.orderId});

  @override
  State<StoreOrderDetailScreen> createState() =>
      _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState extends State<StoreOrderDetailScreen> {
  Map<String, dynamic>? _order;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;
  String? _lastStatus;
  bool _loading = true;
  String? _error;
  String _url = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _url = config['apiEndpoint']?.toString() ?? '';
      if (_url.isEmpty) throw Exception('ไม่พบ API URL');

      await _fetchOrderDetail();
      _listenStatus();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  void _listenStatus() {
    _statusSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (snap) {
            if (!snap.exists) return;
            final data = snap.data() as Map<String, dynamic>?;
            if (data == null) return;

            final newStatus = data['status'] as String?;
            if (newStatus == null) return;

            if (_lastStatus == null) {
              _lastStatus = newStatus;
              return;
            }

            if (newStatus != _lastStatus) {
              _lastStatus = newStatus;
              _fetchOrderDetail();
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _error = 'เกิดข้อผิดพลาด: $e';
              });
            }
          },
        );
  }

  Future<void> _fetchOrderDetail() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_url/order/store/after/detail/${widget.orderId}');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) {
        throw Exception(body['message'] ?? 'ดึงข้อมูลไม่สำเร็จ');
      }

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) throw Exception('ไม่พบข้อมูลออเดอร์');

      _lastStatus = data['status'] as String?;

      if (mounted) {
        setState(() {
          _order = data;
          _loading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _error = 'เซิร์ฟเวอร์ช้า';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  String _fmt(dynamic raw) {
    DateTime? dt;
    if (raw is Map) {
      final seconds = raw['_seconds'];
      if (seconds != null) {
        dt = DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000);
      }
    }
    if (raw is Timestamp) dt = raw.toDate();
    if (raw is String) dt = DateTime.tryParse(raw);
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy  เวลา HH:mm น.', 'th').format(dt);
  }

  String _statusLabel(String s) =>
      {
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
      }[s] ??
      s;

  IconData _statusIcon(String s) =>
      {
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
      }[s] ??
      Icons.circle;

  Widget _buildStatusTimeline(String currentStatus) {
    final isCancelled = currentStatus == 'cancelled';

    final steps = isCancelled
        ? ['cancelled']
        : [
            'waiting_pickup',
            'pickup_in_progress',
            'pickup_completed',
            'waiting_wash',
            'washing',
            'waiting_dry',
            'drying',
            'waiting_delivery',
            'store_pickup_in_progress',
            'delivery_in_progress',
            'completed',
          ];

    final currentIndex = steps.indexOf(currentStatus);
    final total = steps.length;
    final progress = total <= 1 ? 1.0 : currentIndex / (total - 1);

    final Color mainColor = isCancelled
        ? Colors.red
        : currentStatus == 'completed'
            ? Colors.green
            : const Color(0xFF29ABE2);

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
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: AlwaysStoppedAnimation<Color>(mainColor),
            ),
          ),
          const SizedBox(height: 16),
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
                  child: Icon(
                    _statusIcon(currentStatus),
                    size: 20,
                    color: mainColor,
                  ),
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
                        _statusLabel(currentStatus),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

  @override
  Widget build(BuildContext context) {
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
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF29ABE2)),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _fetchOrderDetail,
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
    final orderId = o['order_id'] as String? ?? widget.orderId;
    final price = (o['service_price'] as num? ?? 0).toDouble();
    final delivery = (o['delivery_price'] as num? ?? 0).toDouble();
    final status = o['status'] as String? ?? '';
    final detergentPrice = (o['detergent_price'] as num? ?? 0).toDouble();
    final total = price + delivery + detergentPrice;

    final customerFullname = o['customer_fullname'] as String?;
    final customerPhone = o['customer_phone'] as String?;
    final addressFull = o['address_full'] as String?;

    final riderPickup = o['rider_pickup'] as Map<String, dynamic>?;
    final staff = o['staff'] as Map<String, dynamic>?;
    final riderDelivery = o['rider_delivery'] as Map<String, dynamic>?;

    final serviceMap = {
      'wash_dry': 'ซักและอบ',
      'wash': 'ซักอย่างเดียว',
      'dry': 'อบอย่างเดียว',
    };
    final detergentMap = {
      'no_detergent': 'ไม่ใช้น้ำยาซัก',
      'detergent': 'ใช้น้ำยาซักผ้าของร้าน',
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
                  '#${orderId.toUpperCase().substring(0, orderId.length.clamp(0, 8))}',
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
                      _fmt(o['order_datetime']),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (status.isNotEmpty) _buildStatusTimeline(status),
          if (status.isNotEmpty) const SizedBox(height: 12),
          if (customerFullname != null || addressFull != null)
            _card(
              Icons.person_rounded,
              'ข้อมูลลูกค้า',
              Column(
                children: [
                  if (customerFullname != null) ...[
                    _row('ชื่อ', customerFullname),
                    _row('เบอร์โทร', customerPhone ?? '-'),
                  ],
                  if (addressFull != null) _row('ที่อยู่', addressFull),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _card(
            Icons.local_laundry_service_rounded,
            'รายละเอียดบริการ',
            Column(
              children: [
                _row('รูปแบบบริการ', serviceMap[o['service_type']] ?? '-'),
                _row(
                  'น้ำหนักผ้า',
                  o['wash_dry_weight'] != null
                      ? '${o['wash_dry_weight']} กิโลกรัม'
                      : '-',
                  valueColor: const Color(0xFF29ABE2),
                ),
                if (o['detergent_option'] != null)
                  _row(
                    'น้ำยาซัก',
                    detergentMap[o['detergent_option']] ??
                        o['detergent_option'].toString(),
                  ),
                if (o['note'] != null && o['note'].toString().isNotEmpty)
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
                _row('ค่าน้ำยาซักผ้า', '${detergentPrice.toInt()} ฿'),
                _row('ค่าจัดส่ง', '${delivery.toInt()} ฿'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Flexible(
                      child: Text(
                        'ราคารวมทั้งหมด',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${total.toInt()} ฿',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFF29ABE2),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (riderPickup != null || staff != null || riderDelivery != null)
            _card(
              Icons.people_rounded,
              'ผู้รับผิดชอบ',
              Column(
                children: [
                  if (riderPickup != null)
                    _person(
                      Icons.directions_bike_rounded,
                      'ไรเดอร์รับผ้า',
                      riderPickup,
                    ),
                  if (staff != null) ...[
                    if (riderPickup != null)
                      const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    _person(
                      Icons.local_laundry_service_rounded,
                      'พนักงานซัก',
                      staff,
                    ),
                  ],
                  if (riderDelivery != null) ...[
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                    _person(
                      Icons.delivery_dining_rounded,
                      'ไรเดอร์ส่งผ้า',
                      riderDelivery,
                    ),
                  ],
                ],
              ),
            ),
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _card(IconData icon, String title, Widget child) => Container(
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
                  child:
                      Icon(icon, size: 16, color: const Color(0xFF29ABE2)),
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

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
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

  Widget _person(
    IconData icon,
    String role,
    Map<String, dynamic> data,
  ) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE3F4FC),
            backgroundImage: data['profile_image'] != null
                ? NetworkImage(data['profile_image'])
                : null,
            child: data['profile_image'] == null
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_rounded,
                          size: 12,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          data['phone']?.toString() ?? '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                    if (data['license_plate'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.confirmation_number_outlined,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'ทะเบียนรถ ${data['license_plate']}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    if (data['vehicle_type'] != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            size: 12,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            data['vehicle_type'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _imgBox(String? url, String label) {
    final has = url != null && url.isNotEmpty;
    return Expanded(
      child: Column(
        children: [
          GestureDetector(
            onTap: has
                ? () => showDialog(
                      context: context,
                      builder: (_) => Dialog(
                        backgroundColor: Colors.transparent,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(url!, fit: BoxFit.contain),
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
                  image: has
                      ? DecorationImage(
                          image: NetworkImage(url!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: has
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
                          Icon(Icons.camera_alt_outlined,
                              color: Colors.grey.shade400, size: 30),
                          const SizedBox(height: 4),
                          Text(
                            'ยังไม่มีรูป',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
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