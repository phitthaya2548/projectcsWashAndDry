import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_employees_store.dart';
import 'package:wash_and_dry/screens/store/manage_store/employee_report_screen.dart';
import 'package:wash_and_dry/screens/store/manage_store/manage_applicants_screen.dart';

import 'package:wash_and_dry/service/session_service.dart';

class _Palette {
  static const primary = Color(0xFF0593FF);
  static const primaryTint = Color(0xFFEAF4FF);
  static const mint = Color(0xFF16D957);
  static const mintTint = Color(0xFFE3F8F2);
  static const danger = Color(0xFFE5484D);
  static const dangerTint = Color(0xFFFDEBEC);
  static const ink = Color(0xFF16202A);
  static const muted = Color(0xFF6B7785);
  static const mutedLight = Color.fromARGB(255, 189, 174, 170);
  static const surface = Colors.white;
  static const bg = Color(0xFFF5F7FA);
  static const divider = Color(0xFFE9EDF1);
}

class _StatusInfo {
  final String label;
  final bool active;
  const _StatusInfo(this.label, this.active);
}

class ManageEmployeeScreen extends StatefulWidget {
  const ManageEmployeeScreen({Key? key}) : super(key: key);

  @override
  State<ManageEmployeeScreen> createState() => _ManageEmployeeScreenState();
}

class _ManageEmployeeScreenState extends State<ManageEmployeeScreen> {
  String url = '';
  String _storeId = '';
  bool _isLoading = true;

  List<Employee> _employees = [];

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  List<Employee> get riders =>
      _employees.where((e) => e.isRider && _isKnownStatus(e.status)).toList();

  List<Employee> get laundryStaff =>
      _employees.where((e) => e.isStaff && _isKnownStatus(e.status)).toList();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final config = await Configuration.getConfig();
      final session = Session();
      final storeId = await session.getStoreId();

      if (storeId == null) return;

      url = config['apiEndpoint']?.toString() ?? '';
      _storeId = storeId;

      await _loadEmployees(storeId, search: _searchController.text);
    } catch (e) {
      log('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isKnownStatus(String rawStatus) {
    return rawStatus == 'ONLINE' || rawStatus == 'TEMP_CLOSED';
  }

  Future<void> _loadEmployees(String storeId, {String search = ''}) async {
    try {
      final query = search.trim().isEmpty
          ? ''
          : '?search=${Uri.encodeQueryComponent(search.trim())}';

      final response =
          await http.get(Uri.parse('$url/employees/store/$storeId$query'));

      if (response.statusCode == 200) {
        final data = EmployeeStoreResponse.fromJson(json.decode(response.body));
        if (data.ok) {
          setState(() => _employees = data.data);
        }
      }
    } catch (e) {
      log('Error employees: $e');
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (_storeId.isEmpty) return;
      _loadEmployees(_storeId, search: value);
    });
  }

  Future<void> _deleteRider(String riderId) async {
    try {
      final response = await http.delete(
        Uri.parse('$url/rider/delete/$riderId'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        _showSnack(
          title: 'สำเร็จ',
          message: data['message'] ?? 'ลบ พนักงานรับส่ง สำเร็จ',
          success: true,
        );
        await _loadData();
      } else {
        _showSnack(
          title: 'ข้อผิดพลาด',
          message: data['message'] ?? 'ลบ พนักงานรับส่ง ไม่สำเร็จ',
          success: false,
        );
      }
    } catch (e) {
      _showSnack(
        title: 'ข้อผิดพลาด',
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        success: false,
      );
    }
  }

  Future<void> _deleteStaff(String staffId) async {
    try {
      final response = await http.delete(
        Uri.parse('$url/laundry_staff/delete/$staffId'),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['ok'] == true) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        _showSnack(
          title: 'สำเร็จ',
          message: data['message'] ?? 'ลบพนักงานซักอบสำเร็จ',
          success: true,
        );
        await _loadData();
      } else {
        _showSnack(
          title: 'ข้อผิดพลาด',
          message: data['message'] ?? 'ลบพนักงานซักอบไม่สำเร็จ',
          success: false,
        );
      }
    } catch (e) {
      _showSnack(
        title: 'ข้อผิดพลาด',
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        success: false,
      );
    }
  }

  void _showSnack({required String title, required String message, required bool success}) {
    Get.snackbar(
      title,
      message,
      backgroundColor: success ? _Palette.mint : _Palette.danger,
      colorText: Colors.white,
      icon: Icon(success ? Icons.check_circle_rounded : Icons.error_rounded, color: Colors.white),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 14,
      duration: const Duration(seconds: 3),
    );
  }

  void _showDeleteDialog({
    required String title,
    required String name,
    required VoidCallback onConfirm,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _Palette.dangerTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: _Palette.danger,
                  size: 28,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _Palette.ink,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณต้องการลบ "$name" ใช่หรือไม่',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: _Palette.muted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        backgroundColor: _Palette.bg,
                        foregroundColor: _Palette.muted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _Palette.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ลบ',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Palette.divider),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(fontSize: 13.5, color: _Palette.ink),
        decoration: InputDecoration(
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          hintText: 'ค้นหาจากชื่อ, เบอร์โทร, อีเมล',
          hintStyle: const TextStyle(fontSize: 13, color: _Palette.mutedLight),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _Palette.muted),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: _Palette.muted),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                    setState(() {});
                  },
                ),
        ),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.bg,
      extendBodyBehindAppBar: false,
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'จัดการพนักงาน',
          style: TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
  IconButton(
    tooltip: 'รายงานการทำงาน',
    icon: const Icon(
      Icons.analytics_rounded,
      color: Colors.white,
    ),
    onPressed: () {
      Get.to(
        () => const EmployeeReportScreen(),
      );
    },
  ),

  IconButton(
    tooltip: 'ผู้สมัครรอยืนยัน',
    icon: const Icon(
      Icons.person_add_alt_1_rounded,
      color: Colors.white,
    ),
    onPressed: () async {
      final result = await Get.to(
        () => const ManageApplicantsScreen(),
      );

      if (result == true) {
        _loadData();
      }
    },
  ),
],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: _Palette.primary, strokeWidth: 2.6),
            )
          : RefreshIndicator(
              color: _Palette.primary,
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                children: [
                  _buildSearchBar(),
                  const SizedBox(height: 18),
                  _buildSection(
                    title: 'รายชื่อพนักงานรับส่ง',
                    count: riders.length,
                    tint: _Palette.primaryTint,
                    iconColor: _Palette.primary,
                  ),
                  const SizedBox(height: 12),
                  if (riders.isEmpty)
                    _buildEmptyState(
                      icon: Icons.delivery_dining_rounded,
                      message: _searchController.text.isEmpty
                          ? 'ยังไม่มี พนักงานรับส่ง ในร้านนี้'
                          : 'ไม่พบ พนักงานรับส่ง ที่ตรงกับคำค้นหา',
                    )
                  else
                    ...riders.map((r) => _buildRiderCard(r)),
                  const SizedBox(height: 26),
                  _buildSection(
                    title: 'รายชื่อพนักงานซักอบ',
                    count: laundryStaff.length,
                    tint: _Palette.mintTint,
                    iconColor: _Palette.primary,
                  ),
                  const SizedBox(height: 12),
                  if (laundryStaff.isEmpty)
                    _buildEmptyState(
                      icon: Icons.local_laundry_service_rounded,
                      message: _searchController.text.isEmpty
                          ? 'ยังไม่มีพนักงานซักอบในร้านนี้'
                          : 'ไม่พบพนักงานซักอบที่ตรงกับคำค้นหา',
                    )
                  else
                    ...laundryStaff.map((s) => _buildStaffCard(s)),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required int count,
    required Color tint,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tint,
            borderRadius: BorderRadius.circular(11),
          ),
        ),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _Palette.ink,
              letterSpacing: -0.2,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: _Palette.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _Palette.divider),
          ),
          child: Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _Palette.muted),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.divider, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: _Palette.danger),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(fontSize: 12.5, color: _Palette.muted, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  _StatusInfo _resolveStatus(String rawStatus) {
    switch (rawStatus) {
      case 'ONLINE':
        return const _StatusInfo('ใช้งาน', true);
      case 'TEMP_CLOSED':
        return const _StatusInfo('หยุดงาน', false);
      default:
        return const _StatusInfo('ไม่ทราบสถานะ', false);
    }
  }

  Widget _roleAvatar({
    required String? imageUrl,
    required String fallbackLetter,
    required bool active,
    required IconData roleIcon,
    required Color roleColor,
  }) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? _Palette.mint : _Palette.mutedLight.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _Palette.primaryTint,
              backgroundImage: imageUrl != null && imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Text(
                      fallbackLetter.isNotEmpty ? fallbackLetter.toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: _Palette.primary, fontSize: 16),
                    )
                  : null,
            ),
          ),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: roleColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(roleIcon, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? _Palette.mintTint : _Palette.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _Palette.mint : _Palette.mutedLight,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            status,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? _Palette.mint : _Palette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardShell({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _Palette.ink.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _iconLine({
    required IconData icon,
    required String text,
    required TextStyle style,
    Color iconColor = _Palette.mutedLight,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 12.5, color: iconColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: style,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildRiderCard(Employee rider) {
    final statusInfo = _resolveStatus(rider.status);
    return _cardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roleAvatar(
            imageUrl: rider.profileImage,
            fallbackLetter: rider.fullName.isNotEmpty ? rider.fullName[0] : '?',
            active: statusInfo.active,
            roleIcon: Icons.pedal_bike_rounded,
            roleColor: _Palette.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _iconLine(
                        icon: Icons.person_rounded,
                        text: rider.fullName,
                        iconColor: _Palette.primary,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _Palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _statusPill(statusInfo.label, statusInfo.active),
                  ],
                ),
                const SizedBox(height: 6),
                _iconLine(
                  icon: Icons.alternate_email_rounded,
                  text: rider.email,
                  style: const TextStyle(fontSize: 12, color: _Palette.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _metaTag(Icons.phone_rounded, rider.phone),
                    _metaTag(Icons.two_wheeler_rounded, rider.vehicleType ?? ''),
                    _metaTag(Icons.badge_outlined, (rider.licensePlate ?? '').toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _showDeleteDialog(
                title: 'ยืนยันการลบ พนักงานรับส่ง',
                name: rider.fullName,
                onConfirm: () => _deleteRider(rider.id),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.red),
            splashRadius: 20,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(Employee staff) {
    final statusInfo = _resolveStatus(staff.status);
    return _cardShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _roleAvatar(
            imageUrl: staff.profileImage,
            fallbackLetter: staff.fullName.isNotEmpty ? staff.fullName[0] : '?',
            active: statusInfo.active,
            roleIcon: Icons.local_laundry_service_rounded,
            roleColor: _Palette.mint,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _iconLine(
                        icon: Icons.person_rounded,
                        text: staff.fullName,
                        iconColor: _Palette.mint,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: _Palette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _statusPill(statusInfo.label, statusInfo.active),
                  ],
                ),
                const SizedBox(height: 6),
                _iconLine(
                  icon: Icons.alternate_email_rounded,
                  text: staff.email,
                  style: const TextStyle(fontSize: 12, color: _Palette.muted),
                ),
                const SizedBox(height: 8),
                _metaTag(Icons.phone_rounded, staff.phone),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              _showDeleteDialog(
                title: 'ยืนยันการลบพนักงานซักอบ',
                name: staff.fullName,
                onConfirm: () => _deleteStaff(staff.id),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: _Palette.danger),
            splashRadius: 20,
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.only(left: 6),
          ),
        ],
      ),
    );
  }

  Widget _metaTag(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _Palette.bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: _Palette.muted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _Palette.muted),
          ),
        ],
      ),
    );
  }
}