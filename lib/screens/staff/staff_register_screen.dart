import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_register_laundry_staff_store.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';

class StaffRegisterScreen extends StatefulWidget {
  const StaffRegisterScreen({Key? key}) : super(key: key);

  @override
  State<StaffRegisterScreen> createState() => _StaffRegisterScreenState();
}

class _StaffRegisterScreenState extends State<StaffRegisterScreen> {
  static const primaryBlue = Color(0xFF0593FF);
  static const lightBlue = Color(0xFFEFF7FF);
  static const darkText = Color(0xFF1A2332);

  final _accountFormKey = GlobalKey<FormState>();
  final _personalFormKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _controllers = {
    'email': TextEditingController(),
    'username': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'fullName': TextEditingController(),
    'phone': TextEditingController(),
  };

  File? _profileImage;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  int _currentStep = 0;
  String url = '';

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _controllers.forEach((_, c) => c.dispose());
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {}
  }

  Future<void> _pickImage() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'เลือกรูปภาพโปรไฟล์',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),
              const SizedBox(height: 16),
              _sheetOption(
                icon: Icons.camera_alt_outlined,
                label: 'ถ่ายรูปใหม่',
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final img = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (img != null) setState(() => _profileImage = File(img.path));
                  } catch (_) {
                    _snack('ไม่สามารถถ่ายรูปได้', false);
                  }
                },
              ),
              const SizedBox(height: 10),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'เลือกจากแกลเลอรี่',
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final img = await _picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 1024,
                      maxHeight: 1024,
                      imageQuality: 85,
                    );
                    if (img != null) setState(() => _profileImage = File(img.path));
                  } catch (_) {
                    _snack('ไม่สามารถเลือกรูปภาพได้', false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: lightBlue,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryBlue.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: darkText,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    if (_controllers['password']!.text != _controllers['confirmPassword']!.text) {
      _snack('รหัสผ่านไม่ตรงกัน', false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final session = Session();

      

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$url/laundry_staff/register'),
      );

      request.fields.addAll({
        'email': _controllers['email']!.text.trim(),
        'username': _controllers['username']!.text.trim(),
        'password': _controllers['password']!.text,
        'fullname': _controllers['fullName']!.text.trim(),
        'phone': _controllers['phone']!.text.trim(),
      });

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath('profile_image', _profileImage!.path),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final staffResponse = LaundryStaffResponse.fromJson(json.decode(response.body));

      if (response.statusCode == 200 && staffResponse.ok) {
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        _snack(staffResponse.message ?? 'เกิดข้อผิดพลาด', false);
      }
    } catch (_) {
      _snack('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String message, bool ok) {
    Get.snackbar(
      ok ? 'สำเร็จ' : 'ผิดพลาด',
      message,
      backgroundColor: ok ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
      colorText: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      icon: Icon(
        ok ? Icons.check_circle_outline : Icons.error_outline,
        color: ok ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
      ),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _showSuccessDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_laundry_service,
                  color: Color(0xFF4CAF50),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'เพิ่มพนักงานสำเร็จ!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'บัญชีพนักงานซักอบพร้อมใช้งานแล้ว',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    Get.off(() => const LoginScreen());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'เสร็จสิ้น',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: false,
    );
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0) {
      if (!(_accountFormKey.currentState?.validate() ?? false)) return;

      if (_controllers['password']!.text !=
          _controllers['confirmPassword']!.text) {
        _snack('รหัสผ่านไม่ตรงกัน', false);
        return;
      }
    }

    if (_currentStep < 1) {
      setState(() => _currentStep++);
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _stepProgress() {
    const titles = ['บัญชี', 'ข้อมูลส่วนตัว'];

    return Row(
      children: List.generate(2, (index) {
        final active = index <= _currentStep;
        final current = index == _currentStep;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: current ? 34 : 30,
                      height: current ? 34 : 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: active ? primaryBlue : const Color(0xFFE8EDF3),
                        shape: BoxShape.circle,
                      ),
                      child: index < _currentStep
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 18,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: active
                                    ? Colors.white
                                    : Colors.black38,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      titles[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: current
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: current ? primaryBlue : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 22),
                    color: index < _currentStep
                        ? primaryBlue
                        : const Color(0xFFE8EDF3),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _accountStep() {
    return Form(
      key: _accountFormKey,
      child: Column(
        key: const ValueKey('account'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ข้อมูลบัญชี'),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['username']!,
            hint: 'Username',
            icon: Icons.person_outline,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'กรุณากรอก username';
              if (s.length < 3) return 'อย่างน้อย 3 ตัวอักษร';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['password']!,
            hint: 'Password',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            onToggleObscure: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'กรุณากรอกรหัสผ่าน';
              if (s.length < 6) return 'อย่างน้อย 6 ตัวอักษร';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['confirmPassword']!,
            hint: 'Confirm Password',
            icon: Icons.check_circle_outline,
            obscure: _obscureConfirmPassword,
            onToggleObscure: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            ),
            validator: (v) {
              if ((v ?? '').isEmpty) return 'กรุณายืนยันรหัสผ่าน';
              if (v != _controllers['password']!.text) {
                return 'รหัสผ่านไม่ตรงกัน';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _personalStep() {
    return Form(
      key: _personalFormKey,
      child: Column(
        key: const ValueKey('personal'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('ข้อมูลส่วนตัว'),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['fullName']!,
            hint: 'ชื่อ-นามสกุล',
            icon: Icons.badge_outlined,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'กรุณากรอกชื่อ-นามสกุล' : null,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['email']!,
            hint: 'Email',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'กรุณากรอกอีเมล';
              if (!GetUtils.isEmail(s)) return 'รูปแบบอีเมลไม่ถูกต้อง';
              return null;
            },
          ),
          const SizedBox(height: 12),
          _field(
            controller: _controllers['phone']!,
            hint: 'เบอร์โทรศัพท์',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'กรุณากรอกเบอร์โทร';
              if (s.length < 9) return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _divider(),
          const SizedBox(height: 16),
          _sectionLabel('รูปโปรไฟล์'),
          const SizedBox(height: 8),
          Text(
            'เพิ่มรูปถ่ายพนักงาน',
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.black.withOpacity(0.45),
            ),
          ),
          const SizedBox(height: 12),
          _imagePicker(),
        ],
      ),
    );
  }

  Widget _stepContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: _currentStep == 0
          ? _accountStep()
          : _personalStep(),
    );
  }

  Widget _stepButtons() {
    final isLast = _currentStep == 1;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isLoading ? null : _previousStep,
            style: OutlinedButton.styleFrom(
              foregroundColor: darkText,
              side: const BorderSide(color: Color(0xFFDCE3EA)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              _currentStep == 0 ? 'ย้อนกลับ' : 'ก่อนหน้า',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : isLast
                    ? () {
                        FocusScope.of(context).unfocus();
                        if (_personalFormKey.currentState?.validate() ?? false) {
                          _submitForm();
                        }
                      }
                    : _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryBlue.withOpacity(0.55),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isLast ? 'สมัครพนักงาน' : 'ถัดไป',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.05),
            ),
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
                      offset: Offset(0, -h * 0.02),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      width: 360,
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        22,
                        20,
                        20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                            color: Colors.black.withOpacity(0.11),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Center(
                            child: Text(
                              'สมัครบัญชีพนักงานซักอบ',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black.withOpacity(0.45),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          _stepProgress(),
                          const SizedBox(height: 22),
                          _stepContent(),
                          const SizedBox(height: 24),
                          _stepButtons(),
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

  // ── Helpers ──

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            color: primaryBlue,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: darkText,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  Widget _divider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(0.06),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: primaryBlue, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white.withOpacity(0.90),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0593FF), width: 1.2),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool? obscure,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure ?? false,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      decoration: _inputDeco(
        hint: hint,
        icon: icon,
        suffix: onToggleObscure != null
            ? IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  (obscure ?? false) ? Icons.visibility_off : Icons.visibility,
                  color: primaryBlue.withOpacity(0.6),
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }

Widget _imagePicker() {
  return GestureDetector(
    onTap: _pickImage,
    child: Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 130,
                height: 130,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: primaryBlue.withOpacity(0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _profileImage != null
                      ? Image.file(
                          _profileImage!,
                          width: 122,
                          height: 122,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: primaryBlue.withOpacity(0.08),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 58,
                            color: primaryBlue,
                          ),
                        ),
                ),
              ),

              Positioned(
                right: 2,
                bottom: 5,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    _profileImage == null
                        ? Icons.add_a_photo_rounded
                        : Icons.edit_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            _profileImage == null
                ? 'เพิ่มรูปถ่ายพนักงาน'
                : 'เปลี่ยนรูปโปรไฟล์',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            'แตะที่รูปเพื่อเลือกภาพ',
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.black.withOpacity(0.35),
            ),
          ),
        ],
      ),
    ),
  );
}
}