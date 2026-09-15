import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';

enum ResetStep { email, otp, newPassword }

class ResetPasswordWithEmailOtpScreen extends StatefulWidget {
  const ResetPasswordWithEmailOtpScreen({super.key});

  @override
  State<ResetPasswordWithEmailOtpScreen> createState() =>
      _ResetPasswordWithEmailOtpScreenState();
}

class _ResetPasswordWithEmailOtpScreenState
    extends State<ResetPasswordWithEmailOtpScreen> {
  final _formKey = GlobalKey<FormState>();

  final emailCtl = TextEditingController();
  final otpCtl = TextEditingController();
  final newPassCtl = TextEditingController();
  final confirmPassCtl = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  ResetStep step = ResetStep.email;

  String url = '';

  static const themeColor = Color(0xFF0593FF);

  @override
  void initState() {
    super.initState();
    loadConfig();
    newPassCtl.addListener(() => setState(() {}));
  }

  Future<void> loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {
      setState(() => url = '');
    }
  }

  String? emailValidator(String? value) {
    final email = (value ?? '').trim();

    if (email.isEmpty) {
      return 'กรอกอีเมลก่อน';
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'รูปแบบอีเมลไม่ถูกต้อง';
    }

    return null;
  }

  String? otpValidator(String? value) {
    final otp = (value ?? '').trim();

    if (otp.isEmpty) {
      return 'กรอก OTP ก่อน';
    }

    if (otp.length < 6) {
      return 'OTP ไม่ครบ 6 หลัก';
    }

    return null;
  }

  List<_PasswordRule> get passwordRules => [
        _PasswordRule(
          label: 'อย่างน้อย 8 ตัวอักษร',
          isValid: newPassCtl.text.length >= 8,
        ),
        _PasswordRule(
          label: 'ตัวพิมพ์ใหญ่',
          isValid: RegExp(r'[A-Z]').hasMatch(newPassCtl.text),
        ),
        _PasswordRule(
          label: 'ตัวพิมพ์เล็ก',
          isValid: RegExp(r'[a-z]').hasMatch(newPassCtl.text),
        ),
        _PasswordRule(
          label: 'ตัวเลข',
          isValid: RegExp(r'[0-9]').hasMatch(newPassCtl.text),
        ),
        _PasswordRule(
          label: 'อักขระพิเศษ',
          isValid: RegExp(r'[!@#\$%^&*()_+\-=\[\]{};:"\\|,.<>\/?]')
              .hasMatch(newPassCtl.text),
        ),
      ];

  bool get isPasswordStrongEnough =>
      passwordRules.every((rule) => rule.isValid);

  String? passwordValidator(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'กรอกรหัสผ่านใหม่ก่อน';
    }

    if (!isPasswordStrongEnough) {
      return 'รหัสผ่านยังไม่ตรงตามเงื่อนไขความปลอดภัย';
    }

    return null;
  }

  String? confirmPasswordValidator(String? value) {
    final confirm = value ?? '';

    if (confirm.isEmpty) {
      return 'กรุณายืนยันรหัสผ่านใหม่';
    }

    if (confirm != newPassCtl.text) {
      return 'รหัสผ่านไม่ตรงกัน';
    }

    return null;
  }

  Future<void> sendOtp() async {
    FocusScope.of(context).unfocus();

    if (emailValidator(emailCtl.text) != null) {
      _formKey.currentState!.validate();
      return;
    }

    if (url.isEmpty) {
      showMessage('ไม่พบ apiEndpoint');
      return;
    }

    final email = emailCtl.text.trim();

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse('$url/password/forgot_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          step = ResetStep.otp;
          otpCtl.clear();
        });
        showMessage(data['message'] ?? 'ส่ง OTP แล้ว กรุณาตรวจอีเมล');
      } else {
        showMessage(data['message'] ?? 'ส่ง OTP ไม่สำเร็จ');
      }
    } catch (e) {
      showMessage('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> verifyOtp() async {
    FocusScope.of(context).unfocus();

    if (otpValidator(otpCtl.text) != null) {
      _formKey.currentState!.validate();
      return;
    }

    if (url.isEmpty) {
      showMessage('ไม่พบ apiEndpoint');
      return;
    }

    final email = emailCtl.text.trim();
    final otp = otpCtl.text.trim();

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse('$url/password/verify_otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          step = ResetStep.newPassword;
          newPassCtl.clear();
          confirmPassCtl.clear();
        });
        showMessage(data['message'] ?? 'ยืนยัน OTP สำเร็จ');
      } else {
        showMessage(data['message'] ?? 'OTP ไม่ถูกต้อง');
      }
    } catch (e) {
      showMessage('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> resetPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    if (!isPasswordStrongEnough) {
      showMessage('รหัสผ่านยังไม่ตรงตามเงื่อนไขความปลอดภัย');
      return;
    }

    if (url.isEmpty) {
      showMessage('ไม่พบ apiEndpoint');
      return;
    }

    final email = emailCtl.text.trim();
    final otp = otpCtl.text.trim();
    final newPassword = newPassCtl.text;

    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse('$url/password/reset_password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'otp': otp,
          'newPassword': newPassword,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (!mounted) return;
        await _showSuccessDialog(data['message'] ?? 'รีเซ็ตรหัสผ่านสำเร็จ');
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        showMessage(data['message'] ?? 'รีเซ็ตรหัสผ่านไม่สำเร็จ');
      }
    } catch (e) {
      showMessage('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _showSuccessDialog(String message) {
    return Get.dialog(
      Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'สำเร็จ',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Get.back(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'ตกลง',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showMessage(String message) {
    Get.closeAllSnackbars();

    Get.snackbar(
      'แจ้งเตือน',
      message,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      borderRadius: 16,
      backgroundColor: Colors.white.withOpacity(0.90),
      colorText: Colors.black87,
      duration: const Duration(seconds: 2),
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.06),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          color: Colors.black87,
          size: 18,
        ),
      ),
      shouldIconPulse: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  InputDecoration inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: themeColor),
      prefixIconColor: themeColor,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: themeColor, width: 1.4),
      ),
    );
  }

  Widget sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget stepRow({
    required int stepNumber,
    required String text,
    required bool active,
    required bool done,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: done
                ? Colors.green
                : (active ? themeColor : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(99),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, color: Colors.white, size: 16)
              : Text(
                  '$stepNumber',
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: (active || done) ? Colors.black87 : Colors.grey.shade600,
              fontWeight:
                  (active || done) ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    emailCtl.dispose();
    otpCtl.dispose();
    newPassCtl.dispose();
    confirmPassCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF7FAFC),
        foregroundColor: Colors.white,
        title: const Text(
          'รีเซ็ตรหัสผ่าน',
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () {
            if (step == ResetStep.newPassword) {
              setState(() => step = ResetStep.otp);
            } else if (step == ResetStep.otp) {
              setState(() => step = ResetStep.email);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              sectionTitle(
                'ลืมรหัสผ่านใช่ไหม',
                'กรอกอีเมลของคุณเพื่อรับรหัส OTP และตั้งรหัสผ่านใหม่',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    stepRow(
                      stepNumber: 1,
                      text: 'กรอกอีเมลเพื่อรับ OTP',
                      active: step == ResetStep.email,
                      done: step != ResetStep.email,
                    ),
                    const SizedBox(height: 12),
                    stepRow(
                      stepNumber: 2,
                      text: 'กรอกรหัส OTP ที่ส่งไปยังอีเมล',
                      active: step == ResetStep.otp,
                      done: step == ResetStep.newPassword,
                    ),
                    const SizedBox(height: 12),
                    stepRow(
                      stepNumber: 3,
                      text: 'ตั้งรหัสผ่านใหม่',
                      active: step == ResetStep.newPassword,
                      done: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _buildStepContent(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (step) {
      case ResetStep.email:
        return _buildEmailStep();
      case ResetStep.otp:
        return _buildOtpStep();
      case ResetStep.newPassword:
        return _buildNewPasswordStep();
    }
  }

  Widget _buildEmailStep() {
    return Column(
      children: [
        TextFormField(
          controller: emailCtl,
          keyboardType: TextInputType.emailAddress,
          validator: emailValidator,
          decoration: inputDecoration(
            label: 'อีเมล',
            hint: 'example@gmail.com',
            icon: Icons.mail_outline_rounded,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: !loading ? sendOtp : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: themeColor.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              loading ? 'กำลังส่ง OTP...' : 'ส่ง OTP',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpStep() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: themeColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.mail_outline_rounded, size: 18, color: themeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ส่ง OTP ไปที่ ${emailCtl.text.trim()} แล้ว',
                  style: TextStyle(fontSize: 13, color: themeColor),
                ),
              ),
            ],
          ),
        ),
        TextFormField(
          controller: otpCtl,
          keyboardType: TextInputType.number,
          validator: otpValidator,
          maxLength: 6,
          decoration: inputDecoration(
            label: 'OTP',
            hint: 'กรอกรหัส 6 หลัก',
            icon: Icons.verified_outlined,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: !loading ? verifyOtp : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              disabledBackgroundColor: themeColor.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              loading ? 'กำลังยืนยัน OTP...' : 'ยืนยัน OTP',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        TextButton(
          onPressed: !loading
              ? () {
                  setState(() => step = ResetStep.email);
                }
              : null,
          child: const Text('ยังไม่ได้รับ OTP? กลับไปแก้อีเมล'),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      children: [
        TextFormField(
          controller: newPassCtl,
          obscureText: obscurePassword,
          validator: passwordValidator,
          decoration: inputDecoration(
            label: 'รหัสผ่านใหม่',
            hint: 'อย่างน้อย 8 ตัวอักษร',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              onPressed: () =>
                  setState(() => obscurePassword = !obscurePassword),
              icon: Icon(
                obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPasswordStrongEnough
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 14,
                color: isPasswordStrongEnough
                    ? Colors.green
                    : Colors.grey.shade500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ต้องมีอย่างน้อย 8 ตัว, ตัวพิมพ์ใหญ่, ตัวพิมพ์เล็ก, ตัวเลข, สัญลักษณ์',
                  style: TextStyle(
                    fontSize: 12,
                    color: isPasswordStrongEnough
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: confirmPassCtl,
          obscureText: obscureConfirmPassword,
          validator: confirmPasswordValidator,
          decoration: inputDecoration(
            label: 'ยืนยันรหัสผ่านใหม่',
            hint: 'กรอกรหัสผ่านอีกครั้ง',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              onPressed: () => setState(
                  () => obscureConfirmPassword = !obscureConfirmPassword),
              icon: Icon(
                obscureConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (!loading && isPasswordStrongEnough)
                ? resetPassword
                : null,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: Colors.black87,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.black38,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              loading ? 'กำลังเปลี่ยนรหัสผ่าน...' : 'เปลี่ยนรหัสผ่าน',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasswordRule {
  final String label;
  final bool isValid;

  _PasswordRule({required this.label, required this.isValid});
}