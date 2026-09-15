import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/service/session_service.dart';

const Color kPrimaryBlue = Color(0xFF0593FF);
const Color kPrimaryBlueDark = Color(0xFF0476D9);
const Color kInk = Color(0xFF1A1A1A);
const String pending_confirmation = 'pending_confirmation';

const Map<String, String> _serviceLabels = {
  'wash': 'ซักผ้าอย่างเดียว',
  'dry': 'อบผ้าอย่างเดียว',
  'wash_dry': 'ซัก + อบ',
};

class StoreOrderDetailScreen extends StatefulWidget {
  final String orderId;
  const StoreOrderDetailScreen({super.key, required this.orderId});

  @override
  State<StoreOrderDetailScreen> createState() => _StoreOrderDetailScreenState();
}

class _StoreOrderDetailScreenState extends State<StoreOrderDetailScreen> {
  bool _isLoading = true;
  bool _isAccepting = false;
  bool _isCancelling = false;
  String? _errorMessage;
  Map<String, dynamic>? _order;
  String _apiUrl = '';
  String? _storeId;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await Configuration.getConfig();
      final apiUrl = config['apiEndpoint']?.toString() ?? '';
      if (apiUrl.isEmpty) throw Exception('ไม่พบ API URL');
      _apiUrl = apiUrl;
      _storeId = await Session().getStoreId();

      final uri = Uri.parse('$apiUrl/order/store/detail/${widget.orderId}');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = json.decode(res.body);
      if (body['ok'] != true) {
        throw Exception(body['message']?.toString() ?? 'ดึงข้อมูลไม่สำเร็จ');
      }

      final data = body['data'];
      if (data == null) throw Exception('ไม่พบข้อมูลออเดอร์');

      if (!mounted) return;
      setState(() {
        _order = Map<String, dynamic>.from(data);
        _isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'เซิร์ฟเวอร์ช้า กรุณาลองใหม่';
        _isLoading = false;
      });
    } catch (e) {
      log('loadDetail error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptOrder() async {
    if (_apiUrl.isEmpty || _storeId == null) {
      _showSnack('ไม่พบข้อมูลร้านค้า', Colors.red);
      return;
    }
    setState(() => _isAccepting = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_apiUrl/order/store/accept/${widget.orderId}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'store_id': _storeId}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      final ok = body['ok'] == true;
      final message = body['message']?.toString() ?? (ok ? 'รับออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด');

      if (ok) {
        if (mounted) Get.back(result: true);
        await Future.delayed(const Duration(milliseconds: 300));
        _showSnack(message, const Color(0xFF34C759));
      } else {
        _showSnack(message, Colors.orange);
      }
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ช้า กรุณาลองใหม่', Colors.red);
    } catch (e) {
      log('acceptOrder error: $e');
      _showSnack('เกิดข้อผิดพลาด กรุณาลองใหม่', Colors.red);
    } finally {
      if (mounted) setState(() => _isAccepting = false);
    }
  }

  Future<void> _cancelOrder() async {
    if (_apiUrl.isEmpty || _storeId == null) {
      _showSnack('ไม่พบข้อมูลร้านค้า', Colors.red);
      return;
    }

    final confirmed = await _showCancelConfirmDialog();
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final res = await http
          .post(
            Uri.parse('$_apiUrl/order/store/cancel/${widget.orderId}'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'store_id': _storeId}),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = json.decode(res.body) as Map<String, dynamic>;
      final ok = body['ok'] == true;
      final message = body['message']?.toString() ?? (ok ? 'ยกเลิกออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด');

      if (ok) {
        if (mounted) Get.back(result: true);
        await Future.delayed(const Duration(milliseconds: 300));
        _showSnack(message, const Color(0xFF34C759));
      } else {
        _showSnack(message, Colors.orange);
      }
    } on TimeoutException {
      _showSnack('เซิร์ฟเวอร์ช้า กรุณาลองใหม่', Colors.red);
    } catch (e) {
      log('cancelOrder error: $e');
      _showSnack('เกิดข้อผิดพลาด กรุณาลองใหม่', Colors.red);
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<bool?> _showCancelConfirmDialog() {
    return Get.dialog<bool>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_rounded,
                  color: Colors.red,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'ยกเลิกออเดอร์',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: kInk,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณแน่ใจหรือไม่ว่าต้องการยกเลิกออเดอร์นี้?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(result: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kInk,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ไม่ใช่',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Get.back(result: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ยืนยันยกเลิก',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
      transitionCurve: Curves.easeOutBack,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showSnack(String msg, Color color) {
    final isSuccess = color == const Color(0xFF34C759);
    final isError = color == Colors.red;
    final icon = isSuccess
        ? Icons.check_circle_rounded
        : isError
            ? Icons.error_rounded
            : Icons.info_rounded;

    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 14,
      barBlur: 8,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeIn,
      duration: const Duration(seconds: 3),
      boxShadows: [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  DateTime? _parseTimestamp(dynamic ts) {
    if (ts == null) return null;
    if (ts is Map) {
      final seconds = ts['_seconds'] ?? ts['seconds'];
      if (seconds is num) {
        return DateTime.fromMillisecondsSinceEpoch(seconds.toInt() * 1000);
      }
    }
    return null;
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
    ];
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year + 543} · $hh:$mm น.';
  }

  bool get _canShowActions =>
      !_isLoading &&
      _errorMessage == null &&
      _order != null &&
      (_order!['status']?.toString() ?? '') == pending_confirmation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        flexibleSpace: ClipRRect(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kPrimaryBlue, kPrimaryBlueDark],
              ),
            ),
          ),
        ),
        title: const Text(
          'รายละเอียดออเดอร์',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Get.back(result: true),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryBlue))
          : _errorMessage != null
              ? _buildError()
              : _buildContent(),
      bottomNavigationBar: _canShowActions ? _buildBottomActions() : null,
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(color: Color(0xFFFDEAEA), shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 42, color: Color(0xFFE53935)),
            ),
            const SizedBox(height: 20),
            Text(_errorMessage!, style: const TextStyle(fontSize: 15, color: kInk), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadDetail,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final order = _order!;
    final status = order['status']?.toString() ?? '';
    final statusLabel =
        status == pending_confirmation ? "รอยืนยันคำสั่งซื้อ" : status;
    final serviceLabel = _serviceLabels[order['service_type']?.toString() ?? ''] ?? '-';
    final orderDatetime = _parseTimestamp(order['order_datetime']);

    final note = order['note']?.toString() ?? '';
    final beforeImg = order['before_wash_image']?.toString() ?? '';
    final afterImg = order['after_wash_image']?.toString() ?? '';

    return RefreshIndicator(
      onRefresh: _loadDetail,
      color: kPrimaryBlue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: kToolbarHeight + MediaQuery.of(context).padding.top + 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(statusLabel, orderDatetime),
                  const SizedBox(height: 14),
                  _buildCustomerCard(order),
                  const SizedBox(height: 14),
                  _buildSectionCard(
                    icon: Icons.local_laundry_service_rounded,
                    accent: const Color(0xFF29ABE2),
                    title: 'รายละเอียดบริการ',
                    children: [
                      _InfoRow(label: 'ประเภทบริการ', value: serviceLabel),
                      _InfoRow(
                        label: 'น้ำยาซัก',
                        value: order['detergent_option'] == 'no_detergent'
                            ? 'ไม่ใช้น้ำยาซัก'
                            : order['detergent_option'] == 'detergent'
                                ? 'ใช้น้ำยาซักผ้าของร้าน'
                                : order['detergent_option']?.toString() ?? '-',
                      ),
                      if (note.isNotEmpty) _InfoRow(label: 'หมายเหตุ', value: note),
                    ],
                  ),
                  if (beforeImg.isNotEmpty || afterImg.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _buildImagesCard(beforeImg, afterImg),
                  ],

                  SizedBox(height: _canShowActions ? 12 : 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(String statusLabel, DateTime? orderDatetime) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'หมายเลขออเดอร์',
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '#${widget.orderId.length >= 8 ? widget.orderId.substring(0, 8).toUpperCase() : widget.orderId.toUpperCase()}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withOpacity(0.2)),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 13, color: Colors.white.withOpacity(0.75)),
              const SizedBox(width: 6),
              Text(
                _formatDateTime(orderDatetime),
                style: TextStyle(fontSize: 12.5, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final busy = _isAccepting || _isCancelling;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                      )
                    : const Text('ยกเลิก', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: busy ? null : _acceptOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isAccepting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('รับออเดอร์', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerCard(Map<String, dynamic> order) {
    final profileImage = order['customer_profile_image']?.toString() ?? '';
    final fullname = order['customer_fullname']?.toString() ?? '-';
    final phone = order['customer_phone']?.toString() ?? '';
    final email = order['customer_email']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: kPrimaryBlue.withOpacity(0.12),
                backgroundImage: profileImage.isNotEmpty ? NetworkImage(profileImage) : null,
                onBackgroundImageError: profileImage.isNotEmpty ? (_, __) {} : null,
                child: profileImage.isEmpty ? const Icon(Icons.person_rounded, color: kPrimaryBlue) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  fullname,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: kInk),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'เบอร์โทร', value: phone.isNotEmpty ? phone : '-'),
          if (email.isNotEmpty) _InfoRow(label: 'อีเมล', value: email),
          _InfoRow(label: 'ที่อยู่', value: order['address_full']?.toString() ?? '-'),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color accent,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: accent.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 17, color: accent),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: kInk)),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImagesCard(String beforeImg, String afterImg) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 14, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF00BCD4).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.photo_camera_rounded, size: 17, color: Color(0xFF00BCD4)),
              ),
              const SizedBox(width: 10),
              const Text('รูปภาพผ้า', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: kInk)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (beforeImg.isNotEmpty)
                Expanded(child: _ImageTile(label: 'ก่อนซัก', url: beforeImg)),
              if (beforeImg.isNotEmpty && afterImg.isNotEmpty) const SizedBox(width: 12),
              if (afterImg.isNotEmpty)
                Expanded(child: _ImageTile(label: 'หลังซัก', url: afterImg)),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageTile extends StatelessWidget {
  final String label;
  final String url;

  const _ImageTile({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: 1,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: Colors.grey.shade100,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryBlue),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}