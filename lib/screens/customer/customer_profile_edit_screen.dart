import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/customer/req_editprofile_customer.dart';
import 'package:wash_and_dry/service/session_service.dart';

class ProfileEditCustomer extends StatefulWidget {
  final String customerId;
  const ProfileEditCustomer({super.key, required this.customerId});

  @override
  State<ProfileEditCustomer> createState() => _ProfileEditCustomerState();
}

class _ProfileEditCustomerState extends State<ProfileEditCustomer> {
  String url = '';
  bool isLoading = true;
  bool isSaving = false;
  String? googleId = '';
  Customer? customer;

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? _selectedGender;
  DateTime? _selectedBirthday;
  File? _newProfileImage;

  final ImagePicker _picker = ImagePicker();

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
    loadConfig();
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => url = config['apiEndpoint']?.toString() ?? '');

      if (url.isNotEmpty) {
        await fetchCustomerProfile();
      }
    } catch (e) {
      log('Config error: $e');
      setState(() {
        url = '';
        isLoading = false;
      });
      _showError('ไม่สามารถโหลด Config ได้');
    }
  }

  Future<void> fetchCustomerProfile() async {
    setState(() => isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('$url/customer/profile/${widget.customerId}'),
        headers: {'Content-Type': 'application/json'},
      );

      log('GET Profile - Status: ${response.statusCode}');
      log('GET Profile - Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['ok'] == true) {
          final fetchedCustomer = Customer.fromJson(jsonData['data']);

          _fullnameController.text = fetchedCustomer.fullname;
          _emailController.text = fetchedCustomer.email;
          _phoneController.text = fetchedCustomer.phone;
          _selectedGender =
              fetchedCustomer.gender.isNotEmpty ? fetchedCustomer.gender : null;

          if (fetchedCustomer.birthday != null &&
              fetchedCustomer.birthday!.isNotEmpty) {
            try {
              _selectedBirthday = DateTime.parse(fetchedCustomer.birthday!);
            } catch (e) {
              log('Birthday parse error: $e');
            }
          }

          setState(() {
            customer = fetchedCustomer;
            isLoading = false;
          });
        } else {
          _showError(jsonData['message'] ?? 'ไม่สามารถดึงข้อมูลได้');
          setState(() => isLoading = false);
        }
      } else {
        _showError('เกิดข้อผิดพลาดในการดึงข้อมูล');
        setState(() => isLoading = false);
      }
    } catch (e) {
      log('Fetch error: $e');
      _showError('เกิดข้อผิดพลาด: ${e.toString()}');
      setState(() => isLoading = false);
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
                  'เลือกรูปโปรไฟล์',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _textMain,
                  ),
                ),
                const SizedBox(height: 16),
                _sheetAction(
                  icon: Icons.camera_alt_rounded,
                  iconColor: _primary,
                  title: 'ถ่ายรูป',
                  onTap: () {
                    Get.back();
                    _pickImageFromSource(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                _sheetAction(
                  icon: Icons.photo_library_rounded,
                  iconColor: _primary,
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
    required Color iconColor,
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
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor),
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
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        final file = File(image.path);
        final fileSize = await file.length();

        if (fileSize > 5 * 1024 * 1024) {
          _showError('ไฟล์รูปภาพต้องมีขนาดไม่เกิน 5MB');
          return;
        }

        setState(() {
          _newProfileImage = file;
        });
      }
    } catch (e) {
      log('Pick image error: $e');
      _showError('เกิดข้อผิดพลาดในการเลือกรูปภาพ');
    }
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final minimumDate = DateTime(1900, 1, 1);

    DateTime initialDate = _selectedBirthday ?? DateTime(2000, 1, 1);

    if (initialDate.isBefore(minimumDate)) {
      initialDate = minimumDate;
    }

    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    DateTime tempDate = initialDate;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.cake_rounded,
                          color: _primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'เลือกวันเกิด',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _textMain,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'เลื่อนเพื่อเลือกวัน เดือน และปี',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 230,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              fontSize: 20,
                              color: _textMain,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          dateOrder: DatePickerDateOrder.dmy,
                          initialDateTime: initialDate,
                          minimumDate: minimumDate,
                          maximumDate: today,
                          onDateTimeChanged: (value) {
                            tempDate = DateTime(
                              value.year,
                              value.month,
                              value.day,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textSub,
                            side: const BorderSide(color: _border),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'ยกเลิก',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _selectedBirthday = tempDate;
                            });
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'ตกลง',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
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
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
final session = Session();
    setState(() => isSaving = true);
googleId = await session.getgoogleId();
    try {
      var request = http.MultipartRequest(
        'PUT',
        Uri.parse('$url/customer/profile/${widget.customerId}'),
      );

      request.fields['fullname'] = _fullnameController.text.trim();
      request.fields['email'] = _emailController.text.trim();
      request.fields['phone'] = _phoneController.text.trim();

      if (_selectedGender != null && _selectedGender!.isNotEmpty) {
        request.fields['gender'] = _selectedGender!;
      }

      if (_selectedBirthday != null) {
        request.fields['birthday'] =
            _selectedBirthday!.toIso8601String().split('T')[0];
      }

      if (_newProfileImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _newProfileImage!.path,
          ),
        );
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      log('Update Profile - Status: ${response.statusCode}');
      log('Update Profile - Body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData['ok'] == true) {
          setState(() {
            customer = Customer.fromJson(jsonData['data']);
            _newProfileImage = null;
          });

          try {
            await Session().saveLogin(
              role: 'customer',
              customerId: customer!.customerId,
              fullname: customer!.fullname,
              profileImage: customer!.profileImage,
              phone: customer!.phone,
              googleId: googleId
            );
          } catch (sessionError) {
            log('Session update error: $sessionError');
          }

          Get.snackbar(
            'สำเร็จ',
            'บันทึกข้อมูลเรียบร้อยแล้ว',
            backgroundColor: Colors.green,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
          );

          await Future.delayed(const Duration(milliseconds: 700));
          if (mounted) {
            Navigator.pop(context, customer);
          }
        } else {
          _showError(jsonData['message'] ?? 'ไม่สามารถบันทึกข้อมูลได้');
        }
      } else {
        final jsonData = json.decode(response.body);
        _showError(jsonData['message'] ?? 'เกิดข้อผิดพลาดในการบันทึกข้อมูล');
      }
    } catch (e) {
      log('Save error: $e');
      _showError('เกิดข้อผิดพลาด: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _showError(String message) {
    Get.snackbar(
      'ข้อผิดพลาด',
      message,
      backgroundColor: Colors.red,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  String _formatBirthday(DateTime? date) {
    if (date == null) return 'ไม่ระบุ';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year + 543}';
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
          'แก้ไขโปรไฟล์',
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
            ),
          ),
        ),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : customer == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 60,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      const Text('ไม่พบข้อมูลลูกค้า'),
                      const SizedBox(height: 14),
                      ElevatedButton(
                        onPressed: fetchCustomerProfile,
                        child: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
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
                                    backgroundImage: _newProfileImage != null
                                        ? FileImage(_newProfileImage!)
                                        : (customer!.profileImage.isNotEmpty
                                              ? NetworkImage(customer!.profileImage)
                                              : null)
                                          as ImageProvider?,
                                    child: _newProfileImage == null &&
                                            customer!.profileImage.isEmpty
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
                              customer!.fullname,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _textMain,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '@${customer!.username}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textSub,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'ยอดเงินคงเหลือ ฿${customer!.walletBalance.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleSmall('ข้อมูลส่วนตัว'),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _fullnameController,
                              decoration: _inputDecoration(
                                label: 'ชื่อ-นามสกุล',
                                icon: Icons.person_outline_rounded,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'กรุณากรอกชื่อ-นามสกุล';
                                }
                                if (value.trim().length < 2) {
                                  return 'ชื่อต้องมีอย่างน้อย 2 ตัวอักษร';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _emailController,
                              decoration: _inputDecoration(
                                label: 'อีเมล',
                                icon: Icons.email_outlined,
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'กรุณากรอกอีเมล';
                                }
                                final emailRegex = RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'รูปแบบอีเมลไม่ถูกต้อง';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _phoneController,
                              decoration: _inputDecoration(
                                label: 'เบอร์โทรศัพท์',
                                icon: Icons.phone_outlined,
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'กรุณากรอกเบอร์โทรศัพท์';
                                }
                                final phoneRegex = RegExp(r'^[0-9]{9,10}$');
                                if (!phoneRegex.hasMatch(value.trim())) {
                                  return 'เบอร์โทรศัพท์ต้องเป็นตัวเลข 9-10 หลัก';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _sectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _titleSmall('ข้อมูลเพิ่มเติม'),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
  value: (_selectedGender == 'male' ||
          _selectedGender == 'female' ||
          _selectedGender == 'other')
      ? _selectedGender
      : null,
  decoration: _inputDecoration(
    label: 'เพศ',
    icon: Icons.wc_rounded,
  ),
  hint: const Text('ไม่ระบุ'),
  items: const [
    DropdownMenuItem(
      value: 'male',
      child: Text('ชาย'),
    ),
    DropdownMenuItem(
      value: 'female',
      child: Text('หญิง'),
    ),
    DropdownMenuItem(
      value: 'other',
      child: Text('อื่น ๆ'),
    ),
  ],
  onChanged: (value) {
    setState(() {
      _selectedGender = value;
    });
  },
),
                            const SizedBox(height: 14),
                            InkWell(
                              onTap: _selectDate,
                              borderRadius: BorderRadius.circular(14),
                              child: InputDecorator(
                                decoration: _inputDecoration(
                                  label: 'วันเกิด',
                                  icon: Icons.cake_outlined,
                                  hintText: 'ไม่ระบุ',
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _formatBirthday(_selectedBirthday),
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: _selectedBirthday != null
                                              ? _textMain
                                              : Colors.grey,
                                        ),
                                      ),
                                    ),
                                    if (_selectedBirthday != null)
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedBirthday = null;
                                          });
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: _textSub,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
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
                          onPressed: isSaving ? null : _saveProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                  'บันทึกข้อมูล',
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