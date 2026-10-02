import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/routes/transitions_type.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_profile_store.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_manage_custoomer_screen.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_manage_machine_screen.dart';
import 'package:wash_and_dry/screens/store/store_edit_store_screen.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_manage_employee_screen.dart';
import 'package:wash_and_dry/screens/store/store_review_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstore.dart';

class StoreSettingsScreen extends StatefulWidget {
  const StoreSettingsScreen({super.key});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  String url = '';
  StoreData? storeData;
  bool isLoading = true;
  String? errorMessage;
  String? storeId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      log('API URL: $url');

      final session = Session();
      storeId = await session.getStoreId();
      log('Store ID: $storeId');

      if (url.isEmpty) {
        throw Exception('ไม่พบ API URL');
      }

      if (storeId == null || storeId!.isEmpty) {
        throw Exception('ไม่พบ Store ID - กรุณาเข้าสู่ระบบใหม่');
      }

      await _getStoreProfile();
    } catch (e) {
      log('Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getStoreProfile() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse('$url/store/profile/$storeId');
      log('GET: $uri');

      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      log('Status: ${res.statusCode}');
      log('Body: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = json.decode(res.body);

      if (body['ok'] != true) {
        throw Exception(body['message'] ?? 'ดึงข้อมูลไม่สำเร็จ');
      }

      final storeJson = body['data'];
      if (storeJson == null) {
        throw Exception('ไม่พบข้อมูลร้านค้า');
      }

      if (mounted) {
        setState(() {
          storeData = StoreData.fromJson(storeJson);
          isLoading = false;
        });
      }

      log('Loaded: ${storeData?.storeName}');
    } on TimeoutException {
      if (mounted) {
        setState(() {
          errorMessage = 'เซิร์ฟเวอร์ช้า';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          isLoading = false;
        });
      }
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

                      final session = Session();
                      await session.clear();
                      
                      await Future.delayed(const Duration(milliseconds: 500));
                      
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: storeData == null
    ? null
    : PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: StoreAppBar(
          title: storeData?.storeName ?? '',
          profileImage: storeData?.profileImage,
          storeId: storeData?.storeId ?? '',
        ),
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูลร้าน...'),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          errorMessage!,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Get.offAll(() => const LoginScreen(), transition: Transition.fadeIn);
                          },
                          child: const Text('กลับไปเข้าสู่ระบบ'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        children: [
                          ClipOval(
                            child: storeData?.profileImage.isNotEmpty == true
                                ? Image.network(
                                    storeData!.profileImage,
                                    fit: BoxFit.cover,
                                    width: 150,
                                    height: 150,
                                    errorBuilder: (context, error, stackTrace) {
                                      log('Image load error: $error');
                                      return const Icon(
                                        Icons.local_laundry_service,
                                        size: 60,
                                        color: Colors.white,
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(color: Colors.white),
                                      );
                                    },
                                  )
                                : Image.asset(
                                    'assets/images/logo.png',
                                    width: 160,
                                    height: 160,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      log('Asset load error: $error');
                                      return const Icon(
                                        Icons.local_laundry_service,
                                        size: 60,
                                        color: Colors.white,
                                      );
                                    },
                                  ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "ร้าน ${storeData?.storeName ?? 'ร้านซักอบอบและดี'}",
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 4),
                         
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildMenuItem(
                            icon: 'assets/icons/wash.png',
                            iconFallback: Icons.book_online,
                            title: 'จัดการเครื่องซักผ้า',
                            subtitle: 'เพิ่มและเปิดให้บริการเครื่องซัก',
                            onTap: () {
                              Get.to(() => const ManageMachineScreen());
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: 'assets/icons/customerget.png',
                            iconFallback: Icons.people,
                            title: 'ข้อมูลลูกค้า',
                            subtitle: 'ดูและจัดการข้อมูล',
                            onTap: () {
Get.to(() => const ManageCustomersScreen());
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: 'assets/icons/addemployee.png',
                            iconFallback: Icons.person,
                            title: 'จัดการพนักงาน',
                            subtitle: 'เพิ่ม ลบ และแก้ไข พนักงาน',
                            onTap: () {
                               Get.to(() => const ManageEmployeeScreen());
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: 'assets/icons/review.png',
                            iconFallback: Icons.star_rate_rounded,
                            title: 'รีวิวร้าน',
                            subtitle: 'ดูคะแนนและความคิดเห็นจากลูกค้า',
                            onTap: () {
                              Get.to(() => StoreReviewScreen());
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            icon: 'assets/icons/settings.png',
                            iconFallback: Icons.settings,
                            title: 'ตั้งค่าร้าน',
                            subtitle: 'แก้ไขข้อมูลร้าน',
                            onTap: () async {
  final result = await Get.to(() => StoreEditScreen(storeId: storeId ?? ''));
  if (result == true) {
    await _getStoreProfile();
  }
},
                          ),
                          const SizedBox(height: 12),
                          _buildMenuItem(
  icon: 'assets/icons/logoutstore.png',
  iconFallback: Icons.logout,
  title: 'ออกจากระบบ',
  subtitle: 'ล็อกเอาท์',
  onTap: _logout,
  isLogout: true,
),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMenuItem({
  required String icon,
  required IconData iconFallback,
  required String title,
  required String subtitle,
  required VoidCallback onTap,
  bool isLogout = false, // เพิ่มตัวนี้
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.shade50 : const Color(0xFFE3F2FD),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Image.asset(
            icon,
            width: 28,
            height: 28,
            errorBuilder: (context, error, stackTrace) {
              return Icon(
                iconFallback,
                color: isLogout ? Colors.red : const Color(0xFF2196F3),
                size: 28,
              );
            },
          ),
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isLogout ? Colors.red : const Color(0xFF333333),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isLogout ? Colors.red.shade300 : const Color(0xFF757575),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isLogout ? Colors.red.shade300 : const Color(0xFF757575),
      ),
      onTap: onTap,
    ),
  );
}
}