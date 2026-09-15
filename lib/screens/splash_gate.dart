import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/screens/regiser_employee_store.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/main_shell_customer.dart';
import 'package:wash_and_dry/widgets/main_shell_rider.dart';
import 'package:wash_and_dry/widgets/main_shell_staff.dart';
import 'package:wash_and_dry/widgets/main_shell_store.dart';

class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final session = Session();

    final role = await session.getRole();
    final customerId = await session.getCustomerId();
    final storeId = await session.getStoreId();
    final riderId = await session.getRiderId();
    final staffId = await session.getStaffId();
    final status = await session.getStatus();

    log('role = $role');
    log('customerId = $customerId');
    log('storeId = $storeId');
    log('riderId = $riderId');
    log('staffId = $staffId');
    log('status = $status');

    if (!mounted) return;

    if (role == null || role.isEmpty) {
      Get.offAll(() => const LoginScreen());
      return;
    }

    if (role == 'customer') {
      if (customerId != null && customerId.isNotEmpty) {
        Get.offAll(() => MainShellCustomer());
      } else {
        Get.offAll(() => const LoginScreen());
      }
      return;
    }

    if (role == 'store') {
      if (storeId != null && storeId.isNotEmpty) {
        Get.offAll(() => MainShellStore());
      } else {
        Get.offAll(() => const LoginScreen());
      }
      return;
    }

    if (role == 'rider') {
      if (riderId == null || riderId.isEmpty) {
        Get.offAll(() => const LoginScreen());
        return;
      }

      await _checkEmployeeStore(
        role: 'rider',
        userId: riderId,
      );

      return;
    }

    if (role == 'laundry_staff') {
      if (staffId == null || staffId.isEmpty) {
        Get.offAll(() => const LoginScreen());
        return;
      }

      await _checkEmployeeStore(
        role: 'laundry_staff',
        userId: staffId,
      );

      return;
    }

    Get.offAll(() => const LoginScreen());
  }

  Future<void> _checkEmployeeStore({
    required String role,
    required String userId,
  }) async {
    try {
      final config = await Configuration.getConfig();
      final apiUrl = config['apiEndpoint']?.toString() ?? '';

      final resource =
          role == 'rider'
              ? 'rider'
              : 'staff';

      final response = await http
          .get(
            Uri.parse(
              '$apiUrl/employee_regis_store/$resource/$userId/applied/store',
            ),
          )
          .timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final json =
          jsonDecode(response.body)
              as Map<String, dynamic>;

      final data =
          json['data'] as Map<String, dynamic>?;

      if (data == null) {
        final session = Session();

        await session.clearEmployeeStore();

        if (!mounted) return;

        Get.offAll(
          () => const RegiserEmployeeStore(),
        );

        return;
      }

      final storeId =
          data['store_id']?.toString() ?? '';

      final status =
          data['status']?.toString() ?? '';

      final session = Session();

      await session.updateStoreId(storeId);
      await session.updateStatus(status);

      log('BACKEND storeId = $storeId');
      log('BACKEND status = $status');

      final approved =
          status == 'ONLINE' ||
          status == 'TEMP_CLOSED';

      if (!mounted) return;

      if (storeId.isEmpty || !approved) {
        Get.offAll(
          () => const RegiserEmployeeStore(),
        );

        return;
      }

      if (role == 'rider') {
        Get.offAll(() => MainShellRider());
      } else {
        Get.offAll(() => MainShellStaff());
      }
    } catch (e) {
      log('CHECK EMPLOYEE STORE ERROR: $e');

      final session = Session();

      final storeId =
          await session.getStoreId();

      final status =
          await session.getStatus();

      final approved =
          status == 'ONLINE' ||
          status == 'TEMP_CLOSED';

      if (!mounted) return;

      if (storeId != null &&
          storeId.isNotEmpty &&
          approved) {
        if (role == 'rider') {
          Get.offAll(() => MainShellRider());
        } else {
          Get.offAll(() => MainShellStaff());
        }
      } else {
        Get.offAll(
          () => const RegiserEmployeeStore(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}