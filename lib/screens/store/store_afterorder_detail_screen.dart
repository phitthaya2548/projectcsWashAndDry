import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:intl/intl.dart';

class StoreOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const StoreOrderDetailScreen({super.key, required this.orderId});

  @override
  State<StoreOrderDetailScreen> createState() =>
      _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState extends State<StoreOrderDetailScreen> {
  Map<String, dynamic>? _order;
  Map<String, dynamic>? _customer;
  Map<String, dynamic>? _address;
  Map<String, dynamic>? _riderPickup;
  Map<String, dynamic>? _staff;
  Map<String, dynamic>? _riderDelivery;
  StreamSubscription? _streamSubscription;
  bool _loading = true;
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

  void _listenOrder() {
    setState(() {
      _loading = true;
      _error = null;
    });

    _streamSubscription = FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .snapshots()
        .listen(
          (snap) async {
            if (!snap.exists) {
              setState(() {
                _error = 'ไม่พบข้อมูลออเดอร์';
                _loading = false;
              });
              return;
            }

            final data = snap.data()!;

            Future<Map<String, dynamic>?> resolve(String key) async {
              if (data[key] is DocumentReference) {
                final s = await (data[key] as DocumentReference).get();
                return s.exists ? s.data() as Map<String, dynamic> : null;
              }
              return null;
            }

            _customer = await resolve('customer_id');
            _address = await resolve('address_id');
            _riderPickup = await resolve('rider_pickup_id');
            _staff = await resolve('staff_id');
            _riderDelivery = await resolve('rider_delivery_id');

            if (mounted) {
              setState(() {
                _order = data;
                _loading = false;
              });
            }
          },
          onError: (e) {
            if (mounted) {
              setState(() {
                _error = 'เกิดข้อผิดพลาด: $e';
                _loading = false;
              });
            }
          },
        );
  }

  String _fmt(dynamic raw) {
    DateTime? dt;
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
  Color _statusColor(String s) {
    if (s == 'cancelled') return Colors.red;
    if (s == 'completed') return Colors.green;
    if (s == 'payment_completed') return Colors.green;
    if (s == 'waiting_payment') return Colors.orange;
    return const Color(0xFF29ABE2);
  }

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
                        // FIX: long status labels (e.g. "รับผ้าเรียบร้อยกำลังไปที่ร้าน")
                        // could overflow this constrained row — allow wrap/ellipsis.
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
    final orderId = o['order_id'] as String? ?? widget.orderId;
    final price = (o['service_price'] ?? 0).toDouble();
    final delivery = (o['delivery_price'] ?? 0).toDouble();
    final status = o['status'] as String? ?? '';
    final detergentPrice = (o['detergent_price'] as num? ?? 0).toDouble();
    final total = price + delivery + detergentPrice;

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
          // ── Header Card ──
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
          if (_customer != null || _address != null)
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
                    _row('ที่อยู่', _address!['address_text']?.toString() ?? '-'),
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
                // FIX: this was the actual overflow bug — the label had a typo
                // with a long run of extra "ก" characters, and the Row wasn't
                // wrapped in Flexible/Expanded so it pushed 11px past the edge.
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

          if (_riderPickup != null || _staff != null || _riderDelivery != null)
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
          const SizedBox(height: 12),

          // ── รูปภาพ ──
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
                // FIX: phone + license plate + vehicle type used to sit in one
                // fixed Row and could overflow on narrow screens / long values.
                // Wrap lets items flow onto a new line instead of clipping.
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