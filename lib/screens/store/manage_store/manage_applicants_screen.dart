import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_store_applicants.dart';
import 'package:wash_and_dry/service/session_service.dart';

class _Palette {
  static const primary = Color(0xFF0593FF);
  static const primaryDark = Color(0xFF0476D9);
  static const primaryTint = Color(0xFFEAF4FF);
  static const green = Color(0xFF22C55E);
  static const greenTint = Color(0xFFEAFBF0);
  static const danger = Color(0xFFE5484D);
  static const dangerTint = Color(0xFFFDEBEC);
  static const ink = Color(0xFF16202A);
  static const muted = Color(0xFF6B7785);
  static const mutedLight = Color(0xFFC7CDD4);
  static const surface = Colors.white;
  static const bg = Color(0xFFF5F7FA);
  static const border = Color(0xFFE9EDF1);
}

class ManageApplicantsScreen extends StatefulWidget {
  const ManageApplicantsScreen({super.key});

  @override
  State<ManageApplicantsScreen> createState() => _ManageApplicantsScreenState();
}

class _ManageApplicantsScreenState extends State<ManageApplicantsScreen> {
  String _url = '';
  String _storeId = '';
  String? _error;

  bool _isLoading = true;
  bool _isHiring = false;
  bool _isHiringLoading = false;
  bool _hasChanged = false;

  List<RiderApplicant> _riders = [];
  List<StaffApplicant> _staff = [];
  final Set<String> _processingIds = {};

  int get _total => _riders.length + _staff.length;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final config = await Configuration.getConfig();
      final storeId = await Session().getStoreId();

      if (storeId == null || storeId.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'ไม่พบข้อมูลร้านค้า กรุณาเข้าสู่ระบบใหม่';
          _isLoading = false;
        });
        return;
      }

      _storeId = storeId.trim();
      _url = config['apiEndpoint']?.toString().trim() ?? '';

      if (_url.isEmpty) {
        if (!mounted) return;
        setState(() {
          _error = 'ไม่สามารถโหลดการตั้งค่าเซิร์ฟเวอร์ได้';
          _isLoading = false;
        });
        return;
      }

      await Future.wait([_loadApplicants(), _loadHiringStatus()]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลผู้สมัครไม่สำเร็จ';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadApplicants() async {
    final response = await http
        .get(Uri.parse('$_url/employee_regis_store/store/$_storeId/applicants'))
        .timeout(const Duration(seconds: 12));

    final body = _decodeBody(response.body);

    if (response.statusCode != 200 || body['ok'] != true) {
      throw Exception(
        body['message']?.toString() ?? 'โหลดข้อมูลผู้สมัครไม่สำเร็จ',
      );
    }

    final result = StoreApplicantsResponse.fromJson(body);

    if (!mounted) return;

    setState(() {
      _riders = result.riders;
      _staff = result.staff;
    });
  }

  Future<void> _loadHiringStatus() async {
    final response = await http
        .get(
          Uri.parse('$_url/employee_regis_store/store/$_storeId/hiring-status'),
        )
        .timeout(const Duration(seconds: 12));

    final body = _decodeBody(response.body);

    if (response.statusCode != 200 || body['ok'] != true) {
      return;
    }

    if (!mounted) return;

    setState(() {
      _isHiring = body['data']?['is_hiring'] == true;
    });
  }

  Future<void> _toggleHiring(bool value) async {
    if (_isHiringLoading || _storeId.isEmpty || _url.isEmpty) return;

    final previous = _isHiring;

    setState(() {
      _isHiring = value;
      _isHiringLoading = true;
    });

    try {
      final response = await http
          .put(
            Uri.parse('$_url/employee_regis_store/store/$_storeId/hiring'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'isHiring': value}),
          )
          .timeout(const Duration(seconds: 12));

      final body = _decodeBody(response.body);

      if (response.statusCode != 200 || body['ok'] != true) {
        if (!mounted) return;
        setState(() {
          _isHiring = previous;
        });
        _showSnack(
          title: 'ไม่สำเร็จ',
          message:
              body['message']?.toString() ?? 'เปลี่ยนสถานะรับสมัครไม่สำเร็จ',
          success: false,
        );
        return;
      }

      _hasChanged = true;
      _showSnack(
        title: 'สำเร็จ',
        message:
            body['message']?.toString() ??
            (value ? 'เปิดรับสมัครพนักงานแล้ว' : 'ปิดรับสมัครพนักงานแล้ว'),
        success: true,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isHiring = previous;
      });
      _showSnack(
        title: 'ไม่สำเร็จ',
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHiringLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus({
    required String userId,
    required String role,
    required String action,
    required String name,
  }) async {
    if (_processingIds.contains(userId) || _storeId.isEmpty || _url.isEmpty) {
      return;
    }

    setState(() {
      _processingIds.add(userId);
    });

    try {
      final response = await http
          .put(
            Uri.parse(
              '$_url/employee_regis_store/store/$_storeId/applicant/$userId/status',
            ),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'role': role, 'action': action}),
          )
          .timeout(const Duration(seconds: 12));

      final body = _decodeBody(response.body);

      if (response.statusCode != 200 || body['ok'] != true) {
        _showSnack(
          title: 'ไม่สำเร็จ',
          message: body['message']?.toString() ?? 'ดำเนินการไม่สำเร็จ',
          success: false,
        );
        return;
      }

      if (!mounted) return;

      setState(() {
        _riders.removeWhere((item) => item.riderId == userId);
        _staff.removeWhere((item) => item.staffId == userId);
      });

      _hasChanged = true;

      _showSnack(
        title: 'สำเร็จ',
        message:
            body['message']?.toString() ??
            (action == 'approve'
                ? 'รับ "$name" เข้าร้านแล้ว'
                : 'ปฏิเสธ "$name" แล้ว'),
        success: true,
      );
    } catch (_) {
      _showSnack(
        title: 'ไม่สำเร็จ',
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        success: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          _processingIds.remove(userId);
        });
      }
    }
  }

  Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _confirmReject({
    required String userId,
    required String role,
    required String name,
  }) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: _Palette.danger),
            SizedBox(width: 10),
            Text(
              'ปฏิเสธผู้สมัคร',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _Palette.ink,
              ),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการปฏิเสธ "${name.isNotEmpty ? name : 'ผู้สมัครรายนี้'}" ใช่หรือไม่',
          style: const TextStyle(
            fontSize: 13.5,
            color: _Palette.muted,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _updateStatus(
                userId: userId,
                role: role,
                action: 'reject',
                name: name,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _Palette.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );
  }

  void _showSnack({
    required String title,
    required String message,
    required bool success,
  }) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? _Palette.green : _Palette.danger,
      colorText: Colors.white,
      margin: const EdgeInsets.all(14),
      borderRadius: 14,
      icon: Icon(
        success ? Icons.check_circle_rounded : Icons.error_rounded,
        color: Colors.white,
      ),
    );
  }

  void _close() {
    Navigator.pop(context, _hasChanged);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _close();
      },
      child: Scaffold(
        backgroundColor: _Palette.bg,
        appBar: _buildAppBar(),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: _Palette.primary,
                  strokeWidth: 2.5,
                ),
              )
            : _error != null
            ? _errorView()
            : RefreshIndicator(
                color: _Palette.primary,
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                  children: [
                    _hiringCard(),
                    const SizedBox(height: 18),
                    if (_total == 0)
                      _emptyView()
                    else ...[
                      if (_riders.isNotEmpty) ...[
                        _sectionHeader(
                          title: 'ไรเดอร์',
                          count: _riders.length,
 
                        ),
                        const SizedBox(height: 10),
                        ..._riders.map(
                          (item) => _applicantCard(
                            id: item.riderId,
                            role: 'rider',
                            name: item.fullname,
                            phone: item.phone,
                            email: item.email,
                            profileImage: item.profileImage,
                            appliedAt: item.appliedAt,
                            roleLabel: 'ไรเดอร์',
                            vehicleType: item.vehicleType,
                            licensePlate: item.licensePlate,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (_staff.isNotEmpty) ...[
                        _sectionHeader(
                          title: 'พนักงานซักอบ',
                          count: _staff.length,
                        ),
                        const SizedBox(height: 10),
                        ..._staff.map(
                          (item) => _applicantCard(
                            id: item.staffId,
                            role: 'laundry_staff',
                            name: item.fullname,
                            phone: item.phone,
                            email: item.email,
                            profileImage: item.profileImage,
                            appliedAt: item.appliedAt,
                            roleLabel: 'พนักงานซักอบ',
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        onPressed: _close,
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: Colors.white,
          size: 18,
        ),
      ),
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_Palette.primary, _Palette.primaryDark],
          ),
        ),
      ),
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ผู้สมัครรอยืนยัน',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!_isLoading && _error == null)
            Text(
              '$_total รายการ',
              style: TextStyle(
                color: Colors.white.withOpacity(0.85),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _hiringCard() {
    final color = _isHiring ? _Palette.green : _Palette.muted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.border),
        boxShadow: [
          BoxShadow(
            color: _Palette.ink.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.badge_outlined, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'เปิดรับสมัครพนักงาน',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _Palette.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _isHiring ? 'ร้านกำลังเปิดรับสมัคร' : 'ร้านปิดรับสมัครอยู่',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_isHiringLoading)
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: _Palette.primary,
              ),
            )
          else
            Switch(
              value: _isHiring,
              activeColor: _Palette.green,
              onChanged: _toggleHiring,
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader({
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _Palette.ink,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: _Palette.primaryTint,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: _Palette.primary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _applicantCard({
    required String id,
    required String role,
    required String name,
    required String phone,
    required String email,
    required String profileImage,
    required String roleLabel,

    DateTime? appliedAt,
    String vehicleType = '',
    String licensePlate = '',
  }) {
    final processing = _processingIds.contains(id);
    final displayName = name.isNotEmpty ? name : 'ไม่ระบุชื่อ';
    final roleColor = role == 'rider' ? _Palette.primary : _Palette.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.border),
        boxShadow: [
          BoxShadow(
            color: _Palette.ink.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _avatar(
                name: displayName,
                imageUrl: profileImage,
                color: roleColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _Palette.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    _roleBadge(label: roleLabel, color: roleColor),
                  ],
                ),
              ),
              if (appliedAt != null)
                Text(
                  _formatDate(appliedAt),
                  style: const TextStyle(
                    color: _Palette.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _contactRow(
            Icons.phone_rounded,
            phone.isNotEmpty ? phone : 'ไม่ระบุเบอร์โทร',
          ),
          const SizedBox(height: 7),
          _contactRow(
            Icons.email_rounded,
            email.isNotEmpty ? email : 'ไม่ระบุอีเมล',
          ),
          if (role == 'rider' &&
              (vehicleType.isNotEmpty || licensePlate.isNotEmpty)) ...[
            const SizedBox(height: 10),
            Text(
              [
                if (vehicleType.isNotEmpty) vehicleType,
                if (licensePlate.isNotEmpty) licensePlate.toUpperCase(),
              ].join(' • '),
              style: const TextStyle(
                color: _Palette.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Divider(height: 1, color: _Palette.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  label: 'ปฏิเสธ',
                  icon: Icons.close_rounded,
                  color: _Palette.danger,
                  loading: processing,
                  onPressed: processing
                      ? null
                      : () => _confirmReject(
                          userId: id,
                          role: role,
                          name: displayName,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _actionButton(
                  label: 'รับเข้าร้าน',
                  icon: Icons.check_rounded,
                  color: _Palette.green,
                  loading: processing,
                  onPressed: processing
                      ? null
                      : () => _updateStatus(
                          userId: id,
                          role: role,
                          action: 'approve',
                          name: displayName,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar({
    required String name,
    required String imageUrl,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: CircleAvatar(
        radius: 24,
        backgroundColor: color.withOpacity(0.1),
        backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
        onBackgroundImageError: imageUrl.isNotEmpty ? (_, __) {} : null,
        child: imageUrl.isEmpty
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              )
            : null,
      ),
    );
  }

  Widget _roleBadge({
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 15, color: _Palette.muted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _Palette.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required bool loading,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withOpacity(0.5),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _emptyView() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.border),
      ),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 52, color: _Palette.mutedLight),
          const SizedBox(height: 12),
          const Text(
            'ยังไม่มีผู้สมัครรอยืนยัน',
            style: TextStyle(
              color: _Palette.muted,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isHiring
                ? 'เมื่อมีผู้สมัคร รายการจะปรากฏที่หน้านี้'
                : 'ร้านปิดรับสมัครอยู่',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _Palette.mutedLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return RefreshIndicator(
      color: _Palette.primary,
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(
            Icons.error_outline_rounded,
            size: 56,
            color: _Palette.danger,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              _error ?? 'เกิดข้อผิดพลาด',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _Palette.muted, fontSize: 14),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _Palette.primary,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(local.year, local.month, local.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'วันนี้';
    if (diff == 1) return 'เมื่อวาน';
    if (diff > 1 && diff < 7) return '$diff วันก่อน';

    return '${local.day}/${local.month}/${local.year + 543}';
  }
}
