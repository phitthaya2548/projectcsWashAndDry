import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_register_rider_store.dart';
import 'package:wash_and_dry/screens/login_screen.dart';

class RiderRegisterScreen extends StatefulWidget {
  const RiderRegisterScreen({Key? key}) : super(key: key);

  @override
  State<RiderRegisterScreen> createState() => _RiderRegisterScreenState();
}

class _RiderRegisterScreenState extends State<RiderRegisterScreen> {
  static const primaryBlue = Color(0xFF0593FF);
  static const lightBlue = Color(0xFFEFF7FF);
  static const darkText = Color(0xFF1A2332);

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _controllers = {
    'email': TextEditingController(),
    'username': TextEditingController(),
    'password': TextEditingController(),
    'confirmPassword': TextEditingController(),
    'fullName': TextEditingController(),
    'phone': TextEditingController(),
    'licensePlate': TextEditingController(),
  };

  File? _profileImage;
  String _vehicleType = 'มอเตอร์ไซค์';

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  int _currentStep = 0;
  String url = '';

  final _vehicleTypes = const ['มอเตอร์ไซค์', 'รถยนต์'];

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      if (!mounted) return;
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
                  await _selectImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 10),
              _sheetOption(
                icon: Icons.photo_library_outlined,
                label: 'เลือกจากแกลเลอรี่',
                onTap: () async {
                  Navigator.pop(ctx);
                  await _selectImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 90,
      );

      if (img != null && mounted) {
        setState(() => _profileImage = File(img.path));
      }
    } catch (_) {
      _snack(
        source == ImageSource.camera
            ? 'ไม่สามารถถ่ายรูปได้'
            : 'ไม่สามารถเลือกรูปภาพได้',
        false,
      );
    }
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

  void _nextStep() {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_currentStep == 0 &&
        _controllers['password']!.text !=
            _controllers['confirmPassword']!.text) {
      _snack('รหัสผ่านไม่ตรงกัน', false);
      return;
    }

    if (_currentStep < 2) {
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

  Future<void> _submitForm() async {
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_controllers['password']!.text !=
        _controllers['confirmPassword']!.text) {
      _snack('รหัสผ่านไม่ตรงกัน', false);
      setState(() => _currentStep = 0);
      return;
    }

    if (url.trim().isEmpty) {
      _snack('ไม่พบที่อยู่เซิร์ฟเวอร์ กรุณาลองใหม่อีกครั้ง', false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$url/rider/register'),
      );

      // หน้าแอปแสดงภาษาไทย แต่ส่งไป Backend เป็นภาษาอังกฤษ
      final backendVehicleType =
          _vehicleType == 'มอเตอร์ไซค์' ? 'motorcycle' : 'car';

      request.fields.addAll({
        'email': _controllers['email']!.text.trim(),
        'username': _controllers['username']!.text.trim(),
        'password': _controllers['password']!.text,
        'fullname': _controllers['fullName']!.text.trim(),
        'phone': _controllers['phone']!.text.trim(),
        'vehicle_type': backendVehicleType,
        'license_plate': _controllers['licensePlate']!.text.trim(),
      });

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _profileImage!.path,
          ),
        );
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      final decoded = json.decode(response.body);
      final riderResponse = RiderResponse.fromJson(decoded);

      if (response.statusCode == 200 && riderResponse.ok) {
        if (!mounted) return;
        _showSuccessDialog();
      } else {
        _snack(riderResponse.message ?? 'เกิดข้อผิดพลาด', false);
      }
    } catch (_) {
      _snack('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _snack(String message, bool ok) {
    Get.snackbar(
      ok ? 'สำเร็จ' : 'ผิดพลาด',
      message,
      backgroundColor: ok
          ? const Color(0xFFE8F5E9)
          : const Color(0xFFFFEBEE),
      colorText: ok
          ? const Color(0xFF2E7D32)
          : const Color(0xFFC62828),
      icon: Icon(
        ok ? Icons.check_circle_outline : Icons.error_outline,
        color: ok
            ? const Color(0xFF2E7D32)
            : const Color(0xFFC62828),
      ),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _showSuccessDialog() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
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
                  Icons.delivery_dining,
                  color: Color(0xFF4CAF50),
                  size: 36,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'เพิ่มพนักงานรับส่งสำเร็จ!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: primaryBlue,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'บัญชีพนักงานรับส่งพร้อมใช้งานแล้ว',
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
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'เสร็จสิ้น',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
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
                      offset: Offset(0, -h * 0.02),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Container(
                      width: 380,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
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
                        children: [
                          const Text(
                            'Register',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'สร้างบัญชีพนักงานรับส่ง',
                            style: TextStyle(
                              fontSize: 14.5,
                              color: Colors.black.withOpacity(0.45),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          _stepIndicator(),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: KeyedSubtree(
                                key: ValueKey(_currentStep),
                                child: _buildCurrentStep(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _navigationButtons(),
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

  Widget _stepIndicator() {
    const titles = ['บัญชี', 'ข้อมูลส่วนตัว', 'ยานพาหนะ'];
    const icons = [
      Icons.person_outline,
      Icons.badge_outlined,
      Icons.delivery_dining_outlined,
    ];

    return Row(
      children: List.generate(3, (index) {
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
                      width: current ? 42 : 36,
                      height: current ? 42 : 36,
                      decoration: BoxDecoration(
                        color: active ? primaryBlue : Colors.grey.shade200,
                        shape: BoxShape.circle,
                        boxShadow: current
                            ? [
                                BoxShadow(
                                  color: primaryBlue.withOpacity(0.25),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        index < _currentStep ? Icons.check : icons[index],
                        color: active ? Colors.white : Colors.grey.shade500,
                        size: 19,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      titles[index],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                        color: current
                            ? primaryBlue
                            : active
                                ? darkText
                                : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (index < 2)
                Container(
                  width: 18,
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 23),
                  color: index < _currentStep
                      ? primaryBlue
                      : Colors.grey.shade200,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _accountStep();
      case 1:
        return _personalStep();
      case 2:
        return _vehicleStep();
      default:
        return _accountStep();
    }
  }

  Widget _accountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          icon: Icons.lock_person_outlined,
          title: 'ข้อมูลบัญชี',
          subtitle: 'ตั้งชื่อผู้ใช้และรหัสผ่านสำหรับเข้าสู่ระบบ',
        ),
        const SizedBox(height: 18),
        _field(
          controller: _controllers['username']!,
          hint: 'Username',
          icon: Icons.person_outline,
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.next,
          onToggleObscure: () {
            setState(() => _obscurePassword = !_obscurePassword);
          },
          validator: (v) {
            final s = v ?? '';
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
          textInputAction: TextInputAction.done,
          onToggleObscure: () {
            setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword,
            );
          },
          validator: (v) {
            if ((v ?? '').isEmpty) return 'กรุณายืนยันรหัสผ่าน';
            if (v != _controllers['password']!.text) {
              return 'รหัสผ่านไม่ตรงกัน';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _personalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          icon: Icons.badge_outlined,
          title: 'ข้อมูลส่วนตัว',
          subtitle: 'กรอกข้อมูลติดต่อและรูปถ่ายของพนักงานรับส่ง',
        ),
        const SizedBox(height: 18),
        _field(
          controller: _controllers['fullName']!,
          hint: 'ชื่อ-นามสกุล',
          icon: Icons.badge_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) => (v ?? '').trim().isEmpty
              ? 'กรุณากรอกชื่อ-นามสกุล'
              : null,
        ),
        const SizedBox(height: 12),
        _field(
          controller: _controllers['email']!,
          hint: 'Email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
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
          textInputAction: TextInputAction.done,
          validator: (v) {
            final s = (v ?? '').trim();
            if (s.isEmpty) return 'กรุณากรอกเบอร์โทร';
            if (s.length < 9) return 'เบอร์โทรศัพท์ไม่ถูกต้อง';
            return null;
          },
        ),
        const SizedBox(height: 20),
        _sectionLabel('รูปถ่ายพนักงาน'),
        const SizedBox(height: 10),
        _imagePicker(),
      ],
    );
  }

  Widget _vehicleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stepHeader(
          icon: Icons.delivery_dining_outlined,
          title: 'ข้อมูลยานพาหนะ',
          subtitle: 'ระบุรถที่ใช้สำหรับงง',
        ),
        const SizedBox(height: 18),
        _vehicleDropdown(),
        const SizedBox(height: 12),
        _field(
          controller: _controllers['licensePlate']!,
          hint: 'ทะเบียนรถ',
          icon: Icons.credit_card_outlined,
          textInputAction: TextInputAction.done,
          validator: (v) => (v ?? '').trim().isEmpty
              ? 'กรุณากรอกทะเบียนรถ'
              : null,
        ),
      ],
    );
  }

  Widget _stepHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryBlue.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: primaryBlue, size: 22),
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
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Colors.black.withOpacity(0.48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navigationButtons() {
    final isLastStep = _currentStep == 2;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isLoading ? null : _previousStep,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
            label: Text(_currentStep == 0 ? 'ย้อนกลับ' : 'ก่อนหน้า'),
            style: OutlinedButton.styleFrom(
              foregroundColor: darkText,
              side: BorderSide(color: Colors.black.withOpacity(0.10)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isLoading
                ? null
                : isLastStep
                    ? _submitForm
                    : _nextStep,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Icon(
                    isLastStep
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward_rounded,
                    size: 19,
                  ),
            label: Text(
              _isLoading
                  ? 'กำลังบันทึก...'
                  : isLastStep
                      ? 'สร้างบัญชี'
                      : 'ถัดไป',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              disabledBackgroundColor: primaryBlue.withOpacity(0.55),
              padding: const EdgeInsets.symmetric(vertical: 14),
              elevation: 5,
              shadowColor: primaryBlue.withOpacity(0.30),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
              textStyle: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

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
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryBlue, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC62828), width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFC62828), width: 1.2),
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
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure ?? false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
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
                  (obscure ?? false)
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: primaryBlue.withOpacity(0.6),
                  size: 20,
                ),
              )
            : null,
      ),
    );
  }

  Widget _vehicleDropdown() {
    return DropdownButtonFormField<String>(
      value: _vehicleType,
      isExpanded: true,
      style: const TextStyle(
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
        color: darkText,
      ),
      decoration: _inputDeco(
  hint: 'ประเภทรถ',
  icon: _vehicleType == 'มอเตอร์ไซค์'
      ? Icons.two_wheeler
      : Icons.directions_car,
),

icon: Icon(
  Icons.keyboard_arrow_down_rounded,
  color: Colors.grey.shade500,
  size: 22,
),

items: _vehicleTypes.map((type) {
  return DropdownMenuItem<String>(
    value: type,
    child: Text(type),
  );
}).toList(),

onChanged: _isLoading
    ? null
    : (value) {
        if (value != null) {
          setState(() {
            _vehicleType = value;
          });
        }
      },
    );
  }

  void _showFullImage() {
    if (_profileImage == null) return;

    Get.dialog(
      Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: 300,
                    maxHeight: MediaQuery.of(context).size.height * 0.80,
                  ),
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: Image.file(
                    _profileImage!,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => Get.back(),
                  borderRadius: BorderRadius.circular(20),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _imagePicker() {
  final hasImage = _profileImage != null;

  return Center(
    child: Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              onTap: hasImage ? _showFullImage : _pickImage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 140,
                height: 140,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: hasImage
                        ? primaryBlue.withOpacity(0.35)
                        : Colors.black.withOpacity(0.08),
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
                  child: hasImage
                      ? Image.file(
                          _profileImage!,
                          width: 132,
                          height: 132,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          color: primaryBlue.withOpacity(0.08),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.person_rounded,
                                color: primaryBlue,
                                size: 52,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'เพิ่มรูป',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black.withOpacity(0.45),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),

            Positioned(
              right: 3,
              bottom: 5,
              child: Material(
                color: primaryBlue,
                shape: const CircleBorder(),
                elevation: 3,
                child: InkWell(
                  onTap: _isLoading ? null : _pickImage,
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      hasImage
                          ? Icons.edit_rounded
                          : Icons.add_a_photo_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Text(
          hasImage
              ? 'แตะที่รูปเพื่อดูภาพเต็ม'
              : 'เพิ่มรูปถ่ายพนักงาน',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: darkText,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          hasImage
              ? 'กดไอคอนด้านขวาเพื่อเปลี่ยนรูป'
              : 'แตะเพื่อถ่ายรูปหรือเลือกจากแกลเลอรี่',
          style: TextStyle(
            fontSize: 11.5,
            color: Colors.black.withOpacity(0.35),
          ),
        ),
      ],
    ),
  );
}
}
