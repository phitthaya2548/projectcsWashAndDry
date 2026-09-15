import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_comleted_store.dart';

class StoreCompletedScreen extends StatefulWidget {
  const StoreCompletedScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<StoreCompletedScreen> createState() => _StoreCompletedScreenState();
}

class _StoreCompletedScreenState extends State<StoreCompletedScreen> {
  static const _dark = Color(0xFF1A1A2E);
  static const _primary = Color(0xFF0593FF);

  String _url = '';
  bool _loading = true;
  String? _error;
  StoreCompletedOrder? _order;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _url = config['apiEndpoint']?.toString() ?? '';
      if (_url.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'ไม่พบ API URL';
          _loading = false;
        });
        return;
      }
      await _fetchOrder();
    } catch (e) {
      log('_init error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'เกิดข้อผิดพลาด';
        _loading = false;
      });
    }
  }

  Future<void> _fetchOrder() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$_url/order/store/completed/detail/${widget.orderId}');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        final body = _tryDecode(res.body);
        throw Exception(body?['error'] ?? 'เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final orderJson = body['data'] as Map<String, dynamic>?;
      if (orderJson == null) throw Exception('ไม่พบข้อมูลออเดอร์');

      if (!mounted) return;
      setState(() {
        _order = StoreCompletedOrder.fromJson(orderJson);
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _error = 'เซิร์ฟเวอร์ช้า กรุณาลองใหม่';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _loading = false;
      });
    }
  }

  Map<String, dynamic>? _tryDecode(String body) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  String _serviceLabel(String s) =>
      {
        'wash': 'ซักอย่างเดียว',
        'dry': 'อบอย่างเดียว',
        'wash_dry': 'ซัก + อบ',
      }[s] ??
      s;

  String _formatDate(dynamic raw) {
    if (raw == null) return '-';
    int? seconds;
    if (raw is Map) {
      seconds = raw['_seconds'] as int? ?? raw['seconds'] as int?;
    }
    if (seconds == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    try {
      return DateFormat('d MMM yyyy  เวลา HH:mm น.', 'th').format(dt);
    } catch (_) {
      const m = [
        '',
        'มกราคม','กุมภาพันธ์','มีนาคม','เมษายน','พฤษภาคม','มิถุนายน',
        'กรกฎาคม','สิงหาคม','กันยายน','ตุลาคม','พฤศจิกายน','ธันวาคม',
      ];
      return '${dt.day} ${m[dt.month]} ${dt.year + 543} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} น.';
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
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        foregroundColor: Colors.white,
        title: const Text(
          'ใบเสร็จร้านค้า',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? _errorView()
              : _order == null
                  ? const Center(child: Text('ไม่พบข้อมูล'))
                  : _buildDetail(_order!),
    );
  }

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
                child: const Icon(Icons.error_outline, color: Colors.red, size: 40),
              ),
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14), textAlign: TextAlign.center),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _fetchOrder,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildDetail(StoreCompletedOrder o) {
    final dateStr = _formatDate(o.orderDatetime);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildOrderHeader(o, dateStr),
          const SizedBox(height: 12),

          // บริการ
          _buildSection(
            icon: Icons.local_laundry_service_rounded,
            title: 'รายละเอียดบริการ',
            child: Column(
              children: [
                _buildRow('รูปแบบบริการ', _serviceLabel(o.serviceType)),
                if (o.washDryWeight != null)
                  _buildRow(
                    'น้ำหนักผ้า',
                    '${o.washDryWeight} กิโลกรัม',
                    valueColor: const Color(0xFF29ABE2),
                  ),
                if (o.detergentOption != null)
                  _buildRow(
                    'น้ำยาซัก',
                    o.detergentOption == 'no_detergent'
                        ? 'ไม่ใช้น้ำยาซัก'
                        : o.detergentOption == 'detergent'
                            ? 'ใช้น้ำยาซักผ้าของร้าน'
                            : o.detergentOption ?? '-',
                  ),
                if (o.note != null && o.note!.trim().isNotEmpty)
                  _buildRow('หมายเหตุ', o.note!),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ข้อมูลลูกค้า
          _buildSection(
            icon: Icons.person_rounded,
            title: 'ข้อมูลลูกค้า',
            child: Column(
              children: [
                _buildRow('ชื่อ', o.customerFullname),
                _buildRow('เบอร์โทร', o.customerPhone),
                _buildRow('ที่อยู่', o.addressFull),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ราคา
          _buildSection(
            icon: Icons.receipt_long_rounded,
            title: 'รายละเอียดราคา',
            child: Column(
              children: [
                _buildRow('ค่าบริการ', '${o.servicePrice.toInt()} ฿'),
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
                    const Text(
                      'ราคารวมทั้งหมด',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    Text(
                      '${o.totalAmount.toInt()} ฿',
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
          const SizedBox(height: 12),

          // ผู้รับผิดชอบ
          if (o.riderPickup != null || o.staff != null || o.riderDelivery != null)
            _buildSection(
              icon: Icons.people_rounded,
              title: 'ผู้รับผิดชอบ',
              child: Column(
                children: [
                  if (o.riderPickup != null)
                    _buildPersonRow(
                      icon: Icons.directions_bike_rounded,
                      role: 'ไรเดอร์รับผ้า',
                      fullname: o.riderPickup!.fullname,
                      phone: o.riderPickup!.phone,
                      vehicleType: o.riderPickup!.vehicleType,
                      imageUrl: o.riderPickup!.profileImage,
                      extra: o.riderPickup!.licensePlate,
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
                      vehicleType: o.riderDelivery!.vehicleType,
                      imageUrl: o.riderDelivery!.profileImage,
                      extra: o.riderDelivery!.licensePlate,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: 12),

          // รูปภาพ
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
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── Header ───────────────────────────────────────────────────────────────

  Widget _buildOrderHeader(StoreCompletedOrder o, String dateStr) {
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
              const Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 13),
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

  // ─── Section card ─────────────────────────────────────────────────────────

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
                  color: _dark,
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

  // ─── Row key-value ────────────────────────────────────────────────────────

  Widget _buildRow(String label, String value, {bool isBold = false, Color? valueColor}) {
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
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Person row ───────────────────────────────────────────────────────────

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
                  color: _dark,
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
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                ],
              ),
              if (vehicleType != null && vehicleType.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.directions_car_rounded, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        vehicleType,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ),
                  ],
                ),
              ],
              if (extra != null && extra.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.confirmation_number_outlined, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'ทะเบียนรถ $extra',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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

  // ─── Image box ────────────────────────────────────────────────────────────

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
                          Text(
                            'ยังไม่มีรูป',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade400),
                          ),
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
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}