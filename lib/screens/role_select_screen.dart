import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/screens/rider/rider_register_screen.dart';
import 'package:wash_and_dry/screens/staff/staff_register_screen.dart';
import 'package:wash_and_dry/screens/store/store_register_screen.dart';

import 'customer/customer_register_screen.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0593FF);
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      body: Stack(
        children: [
          // background (ถ้ามีรูป bg)
          Positioned.fill(
            child: Image.asset('assets/images/bg.png', fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.05)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: Offset(
                        0,
                        -h * 0.04,
                      ),
                      child: ClipOval(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          child: Image.asset(
                            'assets/images/logo.png',
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 0),
                    Container(
                      width: 360,
                      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                            color: Colors.black.withOpacity(0.12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'เลือกบทบาทการใช้งาน',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Wash and Dry Delivery',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black.withOpacity(0.55),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _RoleCard(
                            title: 'ลูกค้า',
                            subtitle: 'ใช้บริการสั่งซัก-อบ',
                            icon: Icons.person,
                            onTap: () {
                              Get.to(() => const CustomerRegisterScreen());

                            },
                          ),
                          const SizedBox(height: 12),

                          _RoleCard(
                            title: 'ร้านค้า',
                            subtitle: 'บริการลูกค้า',
                            icon: Icons.store,
                            onTap: () {
                              Get.to(() => const StoreRegisterScreen());
                            },
                          ),
                          const SizedBox(height: 12),

                          
                          _RoleCard(
                            title: 'พนักงานรับส่ง',
                            subtitle: 'รับ-ส่งงานซักผ้า',
                            icon: Icons.delivery_dining,
                            onTap: () {
                              Get.to(() => const RiderRegisterScreen());
                            },
                          ),
                          const SizedBox(height: 12),

                    
                          _RoleCard(
                            title: 'พนักงานซักอบ',
                            subtitle: 'จัดการงานซัก-อบ',
                            icon: Icons.local_laundry_service,
                            onTap: () {
                              Get.to(() => const StaffRegisterScreen());
                            },
                          ),
                          const SizedBox(height: 12),

Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      'เลือกบทบาทให้ตรงกับบัญชีที่คุณใช้',
      style: TextStyle(
        fontSize: 12,
        color: Colors.black.withOpacity(0.45),
        fontWeight: FontWeight.w600,
      ),
      textAlign: TextAlign.center,
    ),
    const SizedBox(height: 15),

    InkWell(
      onTap: () => Navigator.pop(context),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.arrow_back_ios_new,
              size: 14,
              color: Colors.black.withOpacity(0.45),
            ),
            const SizedBox(width: 6),
            Text(
              'ย้อนกลับ',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black.withOpacity(0.45),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  ],
),




                          
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
          ),
          
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF0593FF);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.black.withOpacity(0.06)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryBlue.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryBlue, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.black.withOpacity(0.55),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black.withOpacity(0.35)),
            ],
          ),
        ),
      ),
    );
  }
}