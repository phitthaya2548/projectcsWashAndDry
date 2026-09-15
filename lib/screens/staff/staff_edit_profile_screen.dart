import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_update_laundry_staff_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_laundry_staff_detail_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_update_laundry_staff_store.dart';

class EditLaundryStaffScreen extends StatefulWidget {
  final String staffId;

  const EditLaundryStaffScreen({
    Key? key,
    required this.staffId,
  }) : super(key: key);

  @override
  State<EditLaundryStaffScreen> createState() =>
      _EditLaundryStaffScreenState();
}

class _EditLaundryStaffScreenState extends State<EditLaundryStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _controllers = {
    'email': TextEditingController(),
    'fullName': TextEditingController(),
    'phone': TextEditingController(),
  };

  File? _profileImage;
  String? _profileImageUrl;

  bool _isLoading = false;
  bool _isPageLoading = true;

  String url = '';

  // ---- Shared theme (matches rider / customer profile edit screens) ----
  static const Color _primary = Color(0xFF0593FF);
  static const Color _primaryDark = Color(0xFF0476D9);
  static const Color _background = Color(0xFFF6F8FC);
  static const Color _card = Colors.white;
  static const Color _textMain = Color(0xFF0F172A);
  static const Color _textSub = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _initPage();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _initPage() async {
    setState(() => _isPageLoading = true);
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      await _loadStaffDetail();
    } catch (_) {
      _showSnackbar('ข้อผิดพลาด', 'โหลดข้อมูลไม่สำเร็จ', false);
    } finally {
      if (mounted) {
        setState(() => _isPageLoading = false);
      }
    }
  }

  Future<void> _loadStaffDetail() async {
    try {
      final res = await http.get(
        Uri.parse('$url/laundry_staff/${widget.staffId}'),
      );
      final staffResponse =
          LaundryStaffDetailResponse.fromJson(json.decode(res.body));

      if (res.statusCode == 200 &&
          staffResponse.ok &&
          staffResponse.data != null) {
        final staff = staffResponse.data!;

        _controllers['email']!.text = staff.email;
        _controllers['fullName']!.text = staff.fullname;
        _controllers['phone']!.text = staff.phone;

        setState(() {
          _profileImageUrl = staff.profileImage;
        });
      } else {
        _showSnackbar(
          'ข้อผิดพลาด',
          staffResponse.message ?? 'ไม่พบข้อมูลพนักงาน',
          false,
        );
      }
    } catch (_) {
      _showSnackbar('ข้อผิดพลาด', 'ไม่สามารถโหลดข้อมูลพนักงานได้', false);
    }
  }

  void _showImageSourceDialog() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'เลือกรูปภาพ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetAction(
                  icon: Icons.camera_alt_rounded,
                  title: 'ถ่ายรูป',
                  onTap: () {
                    Get.back();
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _sheetAction(
                  icon: Icons.photo_library_rounded,
                  title: 'เลือกจากแกลเลอรี่',
                  onTap: () {
                    Get.back();
                    _pickImageFromSource(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
    );
  }

  Widget _sheetAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary),
            ),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _textMain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          _showSnackbar('ข้อผิดพลาด', 'ไฟล์รูปภาพต้องมีขนาดไม่เกิน 5MB', false);
          return;
        }

        setState(() => _profileImage = file);
      }
    } catch (_) {
      _showSnackbar('ข้อผิดพลาด', 'เกิดข้อผิดพลาดในการเลือกรูปภาพ', false);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final req = UpdateLaundryStaffRequest(
        email: _controllers['email']!.text.trim(),
        fullname: _controllers['fullName']!.text.trim(),
        phone: _controllers['phone']!.text.trim(),
      );

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$url/laundry_staff/update/${widget.staffId}'),
      );

      request.fields.addAll(
        req.toJson().map((key, value) => MapEntry(key, value.toString())),
      );

      if (_profileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _profileImage!.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      final updateResponse =
          UpdateLaundryStaffResponse.fromJson(json.decode(response.body));

      if (response.statusCode == 200 && updateResponse.ok) {
        Get.back(result: true);
        _showSnackbar(
          'สำเร็จ',
          updateResponse.message ?? 'แก้ไขพนักงานซักอบสำเร็จ',
          true,
        );
      } else {
        _showSnackbar(
          'ข้อผิดพลาด',
          updateResponse.message ?? 'เกิดข้อผิดพลาด',
          false,
        );
      }
    } catch (_) {
      _showSnackbar('ข้อผิดพลาด', 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackbar(String title, String message, bool isSuccess) {
    Get.snackbar(
      title,
      message,
      backgroundColor: isSuccess ? Colors.green : Colors.red,
      colorText: Colors.white,
      icon: Icon(
        isSuccess ? Icons.check_circle : Icons.error,
        color: Colors.white,
      ),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      labelStyle: const TextStyle(color: _textSub),
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: _primary, size: 21),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _titleSmall(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _textMain,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'แก้ไขพนักงานซักอบ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
          flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
      ),
      body: _isPageLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  // ---- Avatar section (same pattern as rider screen) ----
                  _sectionCard(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _primary.withOpacity(0.18),
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 54,
                                backgroundColor: Colors.grey.shade100,
                                backgroundImage: _profileImage != null
                                    ? FileImage(_profileImage!)
                                    : ((_profileImageUrl?.isNotEmpty ?? false)
                                        ? NetworkImage(_profileImageUrl!)
                                        : null) as ImageProvider?,
                                child: _profileImage == null &&
                                        (_profileImageUrl == null ||
                                            _profileImageUrl!.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        size: 54,
                                        color: Colors.grey,
                                      )
                                    : null,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Material(
                                color: _primary,
                                shape: const CircleBorder(),
                                elevation: 1,
                                child: InkWell(
                                  onTap: _showImageSourceDialog,
                                  customBorder: const CircleBorder(),
                                  child: const Padding(
                                    padding: EdgeInsets.all(10),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _controllers['fullName']!.text.isNotEmpty
                              ? _controllers['fullName']!.text
                              : 'พนักงานซักอบ',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _textMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'แก้ไขข้อมูลบัญชีพนักงานซักอบ',
                          style: TextStyle(
                            fontSize: 14,
                            color: _textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ---- Personal info ----
                  _sectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _titleSmall('ข้อมูลส่วนตัว'),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _controllers['fullName'],
                          decoration: _inputDecoration(
                            label: 'ชื่อ-นามสกุล',
                            icon: Icons.badge_outlined,
                          ),
                          validator: (v) => v!.trim().isEmpty
                              ? 'กรุณากรอกชื่อ-นามสกุล'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _controllers['email'],
                          decoration: _inputDecoration(
                            label: 'อีเมล',
                            icon: Icons.email_outlined,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) => v!.trim().isEmpty
                              ? 'กรุณากรอกอีเมล'
                              : !GetUtils.isEmail(v.trim())
                                  ? 'รูปแบบอีเมลไม่ถูกต้อง'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _controllers['phone'],
                          decoration: _inputDecoration(
                            label: 'เบอร์โทรศัพท์',
                            icon: Icons.phone_outlined,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v!.trim().isEmpty
                              ? 'กรุณากรอกเบอร์โทรศัพท์'
                              : v.trim().length != 10
                                  ? 'เบอร์โทรศัพท์ต้องมี 10 หลัก'
                                  : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---- Submit button ----
                  Container(
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_primary, _primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'บันทึกการแก้ไข',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}