import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/screens/customer/customer_address_screen.dart';
import 'package:wash_and_dry/screens/customer/customer_profile_edit_screen.dart';
import 'package:wash_and_dry/screens/customer/wallet/customer_wallet_screen.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/screens/notification_history_screen.dart';
import 'package:wash_and_dry/service/customer_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wash_and_dry/service/notification_api_service.dart';
import 'package:wash_and_dry/service/notification_service.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/drawercustomer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _displayName = '';
  double _walletBalance = 0;
  String? _profileImage;
  bool linkingGoogle = false, isLinked  = false;
  String? _customerId;
  String? _phone;
  String? googleId;
  int _unreadCount =0;
  StreamSubscription<DocumentSnapshot>? _customerListener;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription<String?>? _orderUpdateSub;
  @override
  void initState() {
    super.initState();
    _loadSession();
    _loadUnreadCount();
     _orderUpdateSub = NotificationService().onOrderUpdate.listen((_) {
      if (mounted) _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _customerListener?.cancel();
    super.dispose();
  }
Future<void> _loadUnreadCount() async {
  final count = await NotificationApiService.getMyUnreadCount();
  if (mounted) {
    setState(() => _unreadCount = count);
  }
}
 Future<void> _logout() async {
  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.logout_rounded,
                color: Colors.red.shade400,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ออกจากระบบ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'คุณต้องการออกจากระบบใช่หรือไม่?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      
                      Get.dialog(
                        const Center(
                          child: Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('กำลังออกจากระบบ...'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        barrierDismissible: false,
                      );
                      await GoogleSignIn().signOut();
  await FirebaseAuth.instance.signOut();
                      final session = Session();
                      await session.clear();
                      
                      await Future.delayed(const Duration(milliseconds: 200));
                      
                      Get.offAll(() => const LoginScreen());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ออกจากระบบ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
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
  );
}
  Future<void> _loadSession() async {
    final session = Session();
    final customerId = await session.getCustomerId();
    final phone = await session.getPhone();
        googleId = await session.getgoogleId();
    _phone = phone;
    _customerId = customerId;


   setState(() {
    isLinked = googleId != null && googleId!.isNotEmpty;
  });

    if (customerId != null) {
      _customerListener?.cancel();
      _customerListener = FirebaseFirestore.instance
          .collection('customers')
          .doc(customerId)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.exists && mounted) {
          final data = snapshot.data();
          setState(() {
            _walletBalance = (data?['wallet_balance'] ?? 0).toDouble();
            _displayName = (data?['fullname']?.toString().trim().isNotEmpty ?? false)
                ? data!['fullname'].toString().trim()
                : 'ยังไม่ได้ตั้งชื่อ';
            _profileImage = (data?['profile_image']?.toString().trim().isNotEmpty ?? false)
                ? data!['profile_image'].toString().trim()
                : null;
            _phone = data?['phone']?.toString() ?? phone;
          });
          
          
          await session.saveLogin(
  role: 'customer',
  customerId: customerId,
  fullname: data?['fullname'] ?? '',
  profileImage: data?['profile_image'] ?? '',
  phone: data?['phone'] ?? phone ?? '',
  googleId: googleId,
);
        }
      }, onError: (error) {
        log('Firestore listener error: $error');
      });
    } else {

      final name = await session.getFullname();
      final imageUrl = await session.getProfileImage();
      
      if (!mounted) return;
      setState(() {
        _displayName = (name?.trim().isNotEmpty ?? false)
            ? name!.trim()
            : 'ยังไม่ได้ตั้งชื่อ';
        _profileImage = (imageUrl?.trim().isNotEmpty ?? false)
            ? imageUrl!.trim()
            : null;
      });
    }
  }

  Future<void> _linkGoogle(BuildContext context) async {
    if (linkingGoogle) return;
    setState(() => linkingGoogle = true);

    final g = GoogleSignIn();
    try {
      await g.signOut();
      final gUser = await g.signIn();
      if (gUser == null) {
        setState(() => linkingGoogle = false);
        return;
      }

      final auth = await gUser.authentication;
      final cred = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: auth.accessToken,
      );

      await FirebaseAuth.instance.signInWithCredential(cred);
      final token = await FirebaseAuth.instance.currentUser?.getIdToken(true);

      if (token == null || token.isEmpty) throw Exception("ไม่พบ token");

      final result = await CustomerService().linkGoogle(googleId: token);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.toString())),
      );
      await _loadSession();
    } catch (e) {
      try {
        await FirebaseAuth.instance.signOut();
        await g.disconnect();
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'เชื่อม Google ไม่สำเร็จ (อีเมลนี้มีบัญชีอยู่แล้ว)',
          ),
          action: SnackBarAction(
            label: 'ลองใหม่',
            onPressed: () => _linkGoogle(context),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => linkingGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey, 
      drawer: const Drawer(
        child: DrawerCustomerContent(),
      ),
      backgroundColor: const Color(0xFFF5F7FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('บัญชีของฉัน'),
                  const SizedBox(height: 6),
                  _buildMenuItem(
                    'ข้อมูลส่วนตัว',
                    'แก้ไขข้อมูลส่วนตัว',
                    'assets/icons/profile1.png',
                    const Color(0xFF0593FF),
                    () async {
                      
                      await Get.to(
                        () => ProfileEditCustomer(customerId: _customerId!),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    'กระเป๋าเงิน',
                    'เติมเงินและดูประวัติ',
                    'assets/icons/wallet1.png',
                    const Color(0xFF0593FF),
                    trailing: '${_walletBalance.toStringAsFixed(2)} ฿',
                    trailingColor: Colors.green[700],
                    () {
                     if (_customerId != null) {
  Get.to(
    () => WalletCustomerScreen(),
    arguments: {"fromGet": true},
  );
}
                    },
                  ),
                  const SizedBox(height: 10),
                  _buildMenuItem(
                    'ที่อยู่',
                    'จัดการที่อยู่ของคุณ',
                    'assets/icons/map.png',
                    const Color(0xFF0593FF),
                    () {
                      if (_customerId != null) {
                        Get.to(
                          () => CustomerAddressScreen(customerId: _customerId!),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 18),
                  _buildSectionTitle('การเชื่อมต่อ'),
                  const SizedBox(height: 6),
                  _buildGoogleCard(),
                  const SizedBox(height: 18),
                  _buildLogoutButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              child: Row(
                children: [
                  _circleIconButton(Icons.menu),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'โปรไฟล์',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  _circleIconButton(Icons.notifications_none_rounded),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: _buildProfileCard(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: _profileImage != null && _profileImage!.isNotEmpty
                  ? Image.network(
                      _profileImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Image.asset(
                        'assets/icons/profile_null.png',
                        width: 38,
                        height: 38,
                      ),
                    )
                  : Image.asset(
                      'assets/icons/profile_null.png',
                      width: 38,
                      height: 38,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.22),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.phone_android_outlined,
                        color: Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$_phone',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () async {
             Get.to(
                () => ProfileEditCustomer(customerId: _customerId!),
              );
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_rounded,
                color: Colors.white,
                size: 19,
              ),
              
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 6, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    String subtitle,
    String iconPath,
    Color color,
    VoidCallback? onTap, {
    String? trailing,
    Color? trailingColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 3),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.18), color.withOpacity(0.08)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Image.asset(iconPath, width: 22, height: 22),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: trailingColor ?? const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoogleCard() {
    final user = FirebaseAuth.instance.currentUser;

    return InkWell(
      onTap: linkingGoogle || isLinked ? null : () => _linkGoogle(context),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 3),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F6F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: linkingGoogle
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : isLinked
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.green,
                            size: 26,
                          )
                        : Image.asset(
                            'assets/icons/google.png',
                            width: 26,
                            height: 26,
                          ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    linkingGoogle
                        ? 'กำลังเชื่อม...'
                        : (isLinked
                            ? 'บัญชี Google เชื่อมแล้ว'
                            : 'เชื่อมบัญชี Google'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLinked ? 'บัญชีของคุณปลอดภัย' : 'เชื่อมเพื่อความปลอดภัย',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            if (isLinked) ...[
              Text(
                'เชื่อมแล้ว',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: () => _logout(),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF3B3B), Color(0xFFE31C1C)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/icons/logout.png',
              width: 22,
              height: 22,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            const Text(
              'ออกจากระบบ',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
 Widget _circleIconButton(IconData icon) {
  return InkWell(
  onTap: () async {
    if (icon == Icons.menu) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      final customerId = await Session().getCustomerId();

if (customerId == null || customerId.isEmpty) return;

await Get.to(
  () => NotificationHistoryScreen(
    userId: customerId,
    userRole: 'customer',
  ),
);
      _loadUnreadCount();
    }
  },
    borderRadius: BorderRadius.circular(25),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        if (icon != Icons.menu && _unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}
}