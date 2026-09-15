import 'dart:convert';
import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_getx_widget.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_profile_customer.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';

class _Palette {
  static const ink = Color(0xFF1E2A33);
  static const blue = Color(0xFF0593FF);
  static const blueDeep = Color(0xFF0476D9);
  static const bg = Color(0xFFF7F9FB);
  static const surface = Colors.white;
  static const muted = Color(0xFF6B7680);
  static const line = Color(0xFFE7ECF1);
}

class DrawerCustomerContent extends StatefulWidget {
  const DrawerCustomerContent({super.key});

  @override
  State<DrawerCustomerContent> createState() => DrawerCustomerContentState();
}

class DrawerCustomerContentState extends State<DrawerCustomerContent> {
  final Session _session = Session();

  String? _fullname;
  String? _phone;
  String? _profileImage;
  String? _email;
  String? _gender;
  DateTime? _birthday;
  double? _walletBalance;
  bool _isLoading = true;
  String url = '';
  String? _customerId;

  static const List<String> _thaiMonths = [
    '',
    'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน',
    'พฤษภาคม', 'มิถุนายน', 'กรกฎาคม', 'สิงหาคม',
    'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> refresh() async {
    setState(() => _isLoading = true);
    await fetchCustomerProfile();
  }

  Future<void> _loadConfig() async {
    final config = await Configuration.getConfig();
    final customerId = await Session().getCustomerId();

    setState(() {
      url = config['apiEndpoint']?.toString() ?? '';
      _customerId = customerId;
    });

    await fetchCustomerProfile();
  }

  Future<void> fetchCustomerProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$url/customer/profile/$_customerId'),
        headers: {'Content-Type': 'application/json'},
      );

      log('GET Profile - Status: ${response.statusCode}');
      log('GET Profile - Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['ok'] == true) {
          final profile = CustomerProfile.fromJson(jsonData['data']);

          if (!mounted) return;
          setState(() {
            _fullname = profile.fullname;
            _email = profile.email;
            _phone = profile.phone;
            _gender = profile.gender;
            _birthday = profile.birthday;
            _profileImage = profile.profileImage;
            _walletBalance = profile.walletBalance;
            _isLoading = false;
          });
        } else {
          log('API returned ok=false: ${jsonData['message']}');
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
        log('HTTP error: ${response.statusCode}');
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      log('fetchCustomerProfile error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String genderThai(String? gender) {
    if (gender == 'female') {
      return 'หญิง';
    } else if (gender == 'male') {
      return 'ชาย';
    } else {
      return 'อื่นๆ';
    }
  }

  String birthdayThai(DateTime? birthday) {
    if (birthday == null) return 'ไม่ระบุ';
    return '${birthday.day} ${_thaiMonths[birthday.month]} ${birthday.year + 543}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _Palette.bg,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildHeader(),
                const SizedBox(height: 18),
                if (_isLoading)
                  _buildSkeleton()
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      children: [
                        _buildWalletChip(),
                        const SizedBox(height: 16),
                        _infoCard(
                          label: 'อีเมล',
                          value: (_email?.isNotEmpty == true) ? _email! : 'ไม่ระบุ',
                        ),
                        const SizedBox(height: 10),
                        _infoCard(
                          label: 'เพศ',
                          value: genderThai(_gender),
                        ),
                        const SizedBox(height: 10),
                        _infoCard(
                          label: 'วันเกิด',
                          value: birthdayThai(_birthday),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (!_isLoading)
            Container(
              padding: EdgeInsets.fromLTRB(
                18,
                12,
                18,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                color: _Palette.bg,
                border: Border(top: BorderSide(color: _Palette.line)),
              ),
              child: _logoutButton(),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 44),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_Palette.blue, _Palette.blueDeep],
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(28),
              bottomRight: Radius.circular(28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.55), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white,
                      backgroundImage: (_profileImage != null && _profileImage!.isNotEmpty)
                          ? NetworkImage(_profileImage!)
                          : null,
                      child: (_profileImage == null || _profileImage!.isEmpty)
                          ? const Icon(Icons.person_rounded, size: 32, color: _Palette.blueDeep)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isLoading ? 'กำลังโหลด...' : (_fullname ?? 'ไม่ระบุชื่อ'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.call_outlined, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              _isLoading ? '' : (_phone ?? 'ไม่ระบุเบอร์โทร'),
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWalletChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _Palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ยอดเงินคงเหลือ',
                  style: TextStyle(fontSize: 12.5, color: _Palette.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(_walletBalance ?? 0).toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({required String label, required String value}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _Palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.line),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: _Palette.muted)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: _Palette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Colors.red, width: 1.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: _confirmLogout,
        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.red),
        label: const Text(
          'ออกจากระบบ',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _confirmLogout() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.red, size: 26),
              ),
              const SizedBox(height: 16),
              const Text(
                'ออกจากระบบ?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _Palette.ink),
              ),
              const SizedBox(height: 8),
              const Text(
                'คุณต้องการออกจากระบบใช่หรือไม่',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: _Palette.muted, height: 1.4),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: _Palette.line, width: 1.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () => Get.back(),
                      child: const Text('ยกเลิก', style: TextStyle(color: _Palette.muted, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () async {
                        Get.back();
                        await _session.clear();
                        await GoogleSignIn().signOut();
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        Get.offAll(() => const LoginScreen());
                      },
                      child: const Text('ออกจากระบบ', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );
  }

  Widget _buildSkeleton() {
    Widget bar({double w = double.infinity, double h = 14}) => Container(
          width: w,
          height: h,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: _Palette.line,
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _Palette.line),
            ),
          ),
          const SizedBox(height: 10),
          bar(h: 56),
          bar(h: 56),
        ],
      ),
    );
  }
}