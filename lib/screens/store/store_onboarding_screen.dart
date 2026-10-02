import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';

import 'package:wash_and_dry/models/req/store/req_edit_store.dart';

import 'package:wash_and_dry/screens/pickaddress_frommap.dart';
import 'package:wash_and_dry/service/address_service.dart';
import 'package:wash_and_dry/widgets/main_shell_store.dart';

const _primaryColor = Colors.blue;
const _lightBlueBackground = Color(0xFFE8F2FE);
const _successColor = Color(0xFF34A853);
const _dangerColor = Color(0xFFE53935);
const _pageBackground = Color(0xFFF6F8FB);
const _borderColor = Color(0xFFE6E9EF);
const _mutedText = Color(0xFF8A93A3);

const _stepTitles = ["ข้อมูลร้าน", "ที่ตั้ง & เวลา", "รูปโฆษณา"];
const _stepCount = 3;

class StoreOnboardingScreen extends StatefulWidget {
  final String storeId;
  const StoreOnboardingScreen({super.key, required this.storeId});
  @override
  State<StoreOnboardingScreen> createState() => _StoreOnboardingScreenState();
}

class _StoreOnboardingScreenState extends State<StoreOnboardingScreen> {
  int _currentStep = 0;
  final _pageController = PageController();
  final _formKeys = List.generate(_stepCount, (_) => GlobalKey<FormState>());

  final _storeNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _serviceRadiusController = TextEditingController();
  final _openingTimeController = TextEditingController();
  final _closingTimeController = TextEditingController();
  final _minDeliveryController = TextEditingController();
  final _maxDeliveryController = TextEditingController();
  final _detergentPriceController = TextEditingController();
  final _facebookController = TextEditingController();
  final _lineIdController = TextEditingController();

  List<TextEditingController> get _allControllers => [
    _storeNameController,
    _phoneController,
    _emailController,
    _addressController,
    _serviceRadiusController,
    _openingTimeController,
    _closingTimeController,
    _minDeliveryController,
    _maxDeliveryController,
    _detergentPriceController,
    _facebookController,
    _lineIdController,
  ];

  File? _logoImage;
  List<File> _adImages = [];
  final _imagePicker = ImagePicker();
  bool _isLoading = false;
  String? _errorMessage;
  String? _apiEndpoint;

  @override
  void initState() {
    super.initState();
    _loadApiConfig();
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _allControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadApiConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => _apiEndpoint = config['apiEndpoint']);
    } catch (e) {
      setState(() => _errorMessage = "โหลดการตั้งค่าไม่สำเร็จ");
    }
  }

  String? _validateRequired(String? value) =>
      (value?.trim().isEmpty ?? true) ? "จำเป็นต้องกรอก" : null;

  String? _validateNumber(String? value) =>
      _validateRequired(value) ??
      (double.tryParse(value!) == null ? "กรอกตัวเลข" : null);

  String? _validateNonNegativeNumber(String? value) {
    final error = _validateNumber(value);
    if (error != null) return error;
    return (double.parse(value!) < 0) ? "ต้องไม่ติดลบ" : null;
  }

  String? _validateTime(String? value) =>
      _validateRequired(value) ??
      (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(value!)
          ? "รูปแบบ HH:MM"
          : null);

  String? _validatePhone(String? value) =>
      _validateRequired(value) ??
      (!RegExp(r'^0[0-9]{9}$').hasMatch(value!) ? "รูปแบบ 0XXXXXXXXX" : null);

  String? _validateEmail(String? value) =>
      _validateRequired(value) ??
      (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)
          ? "อีเมลไม่ถูกต้อง"
          : null);

  Future<void> _showTimeWheelPicker(
    TextEditingController controller,
    String title,
  ) async {
    final parts = controller.text.split(":");
    int selectedHour = int.tryParse(parts.isNotEmpty ? parts[0] : "") ?? 0;
    int selectedMinute = int.tryParse(parts.length > 1 ? parts[1] : "") ?? 0;

    selectedHour = selectedHour.clamp(0, 23).toInt();
    selectedMinute = selectedMinute.clamp(0, 59).toInt();

    final hourController = FixedExtentScrollController(
      initialItem: selectedHour,
    );
    final minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );

    int tempHour = selectedHour;
    int tempMinute = selectedMinute;

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
                          color: _lightBlueBackground,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.schedule_rounded,
                          color: _primaryColor,
                          size: 22,
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
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              "เลื่อนขึ้นลงเพื่อเลือกเวลา",
                              style: TextStyle(
                                fontSize: 13,
                                color: _mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      color: _pageBackground,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: Text(
                                  "ชั่วโมง",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: hourController,
                                  itemExtent: 44,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  selectionOverlay: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onSelectedItemChanged: (index) {
                                    tempHour = index;
                                  },
                                  children: List.generate(
                                    24,
                                    (index) => Center(
                                      child: Text(
                                        index.toString().padLeft(2, "0"),
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 38),
                          child: Text(
                            ":",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 14),
                                child: Text(
                                  "นาที",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _mutedText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: minuteController,
                                  itemExtent: 44,
                                  useMagnifier: true,
                                  magnification: 1.08,
                                  selectionOverlay: Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _primaryColor.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onSelectedItemChanged: (index) {
                                    tempMinute = index;
                                  },
                                  children: List.generate(
                                    60,
                                    (index) => Center(
                                      child: Text(
                                        index.toString().padLeft(2, "0"),
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _mutedText,
                            side: const BorderSide(color: _borderColor),
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "ยกเลิก",
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
                            controller.text =
                                "${tempHour.toString().padLeft(2, '0')}:${tempMinute.toString().padLeft(2, '0')}";
                            Navigator.pop(sheetContext);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size.fromHeight(50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "ตกลง",
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

    hourController.dispose();
    minuteController.dispose();
  }

  String? _validateMaxDelivery(String? value) {
    final error = _validateNumber(value);
    if (error != null) return error;
    return (double.parse(value!) <
            (double.tryParse(_minDeliveryController.text) ?? 0))
        ? "ต้องมากกว่าค่าต่ำสุด"
        : null;
  }

  Future<void> _pickLogoImage(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _logoImage = File(picked.path));
  }

  Future<void> _pickAdImages(ImageSource source) async {
    final remainingSlots = 5 - _adImages.length;

    if (remainingSlots <= 0) {
      _showError("เพิ่มรูปได้สูงสุด 5 รูป");
      return;
    }

    if (source == ImageSource.camera) {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        imageQuality: 80,
      );

      if (picked == null) return;

      setState(() {
        _adImages.add(File(picked.path));
      });

      return;
    }

    final pickedList = await _imagePicker.pickMultiImage(
      maxWidth: 1200,
      imageQuality: 80,
    );

    if (pickedList.isEmpty) return;

    final selected = pickedList
        .take(remainingSlots)
        .map((image) => File(image.path))
        .toList();

    setState(() {
      _adImages.addAll(selected);
    });

    if (pickedList.length > remainingSlots) {
      _showError("เพิ่มได้สูงสุด 5 รูป เลือกมาให้แล้ว $remainingSlots รูป");
    }
  }

  void _showImagePickerSheet({
    required String title,
    required VoidCallback onGallery,
    required VoidCallback onCamera,
    VoidCallback? onDelete,
  }) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _pickerSheetTile(
            icon: Icons.photo_library_outlined,
            label: 'เลือกจากแกลเลอรี่',
            onTap: () {
              Navigator.pop(context);
              onGallery();
            },
          ),
          _pickerSheetTile(
            icon: Icons.camera_alt_outlined,
            label: 'ถ่ายรูป',
            onTap: () {
              Navigator.pop(context);
              onCamera();
            },
          ),
          if (onDelete != null)
            _pickerSheetTile(
              icon: Icons.delete_outline,
              label: 'ลบรูป',
              color: _dangerColor,
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
        ],
      ),
    ),
  );

  Widget _pickerSheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = _primaryColor,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color == _primaryColor
            ? _lightBlueBackground
            : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 20),
    ),
    title: Text(
      label,
      style: TextStyle(
        color: color == _dangerColor ? _dangerColor : Colors.black87,
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: onTap,
  );

  void _showLogoPickerDialog() => _showImagePickerSheet(
    title: 'เลือกโลโก้ร้าน',
    onGallery: () => _pickLogoImage(ImageSource.gallery),
    onCamera: () => _pickLogoImage(ImageSource.camera),
    onDelete: _logoImage != null
        ? () => setState(() => _logoImage = null)
        : null,
  );

  void _showAdImagePickerDialog() => _showImagePickerSheet(
    title: 'เพิ่มรูปโฆษณา',
    onGallery: () => _pickAdImages(ImageSource.gallery),
    onCamera: () => _pickAdImages(ImageSource.camera),
  );

  void _goToNextStep() {
    if (!(_formKeys[_currentStep].currentState?.validate() ?? false)) return;
    if (_currentStep < _stepCount - 1) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _submitForm();
    }
  }

  void _goToPreviousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submitForm() async {
    if (_apiEndpoint == null) {
      setState(() => _errorMessage = "กำลังโหลด...");
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await _saveStoreProfile();
      if (_adImages.isNotEmpty) await _uploadAdImages();
      if (!mounted) return;
      _showSuccess("บันทึกข้อมูลร้านค้าเรียบร้อย");
      Get.offAll(() => MainShellStore());
    } catch (e) {
      log("Submit error: $e");
      setState(
        () => _errorMessage = e.toString().replaceFirst("Exception: ", ""),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  StoreProfileModel _buildProfileModel() {
    return StoreProfileModel(
      storeName: _storeNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      serviceRadius: double.parse(_serviceRadiusController.text.trim()),
      openingHours: _openingTimeController.text.trim(),
      closingHours: _closingTimeController.text.trim(),
      deliveryMin: double.parse(_minDeliveryController.text.trim()),
      deliveryMax: double.parse(_maxDeliveryController.text.trim()),
      detergentPrice: double.parse(_detergentPriceController.text.trim()),
      facebook: _facebookController.text.trim().isEmpty
          ? null
          : _facebookController.text.trim(),
      lineId: _lineIdController.text.trim().isEmpty
          ? null
          : _lineIdController.text.trim(),
    );
  }

  Future<void> _saveStoreProfile() async {
    final geo = await geocodeFromAddress(_addressController.text.trim());
    final profile = _buildProfileModel().copyWithCoordinates(
      latitude: geo.lat,
      longitude: geo.lng,
    );

    final uri = Uri.parse("$_apiEndpoint/store/profile/${widget.storeId}");
    http.Response response;

    if (_logoImage != null) {
      if (!await _logoImage!.exists()) {
        throw Exception("ไฟล์รูปหายไป");
      }

      final request = http.MultipartRequest('PUT', uri)
        ..fields.addAll(profile.toFormFields())
        ..files.add(
          await http.MultipartFile.fromPath('profile_image', _logoImage!.path),
        );

      response = await http.Response.fromStream(await request.send());
    } else {
      response = await http.put(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(profile.toJson()),
      );
    }

    final result = ApiResponseModel.fromJson(jsonDecode(response.body));
    if (response.statusCode != 200) {
      throw Exception(result.message ?? "อัปเดตไม่สำเร็จ");
    }
    result.throwIfNotOk("อัปเดตไม่สำเร็จ");
  }

  Future<void> _uploadAdImages() async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse("$_apiEndpoint/store/images/${widget.storeId}"),
    );
    for (final file in _adImages) {
      if (await file.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('store_images', file.path),
        );
      }
    }
    if (request.files.isEmpty) return;

    final response = await http.Response.fromStream(await request.send());
    final result = ApiResponseModel.fromJson(jsonDecode(response.body));
    result.throwIfNotOk("อัปโหลดรูปไม่สำเร็จ");
  }

  void _showError(String message) => Get.snackbar(
    "ข้อผิดพลาด",
    message,
    backgroundColor: _dangerColor,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
    icon: const Icon(Icons.error_outline, color: Colors.white),
  );

  void _showSuccess(String message) => Get.snackbar(
    "สำเร็จ",
    message,
    backgroundColor: _successColor,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? hint,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) => TextFormField(
    controller: controller,
    style: const TextStyle(fontSize: 15),
    readOnly: readOnly,
    onTap: onTap,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, color: _mutedText, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _pageBackground,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primaryColor, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _dangerColor),
      ),
    ),
    validator: validator,
    keyboardType: keyboardType,
    maxLines: maxLines,
  );

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> fields,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 18),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _lightBlueBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _primaryColor, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: _mutedText),
            ),
          ),
        ],
        const SizedBox(height: 16),
        for (int i = 0; i < fields.length; i++) ...[
          fields[i],
          if (i != fields.length - 1) const SizedBox(height: 14),
        ],
      ],
    ),
  );

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _mutedText,
      ),
    ),
  );

  Widget _buildScreenHeader(String title, String description) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 13, color: _mutedText),
        ),
      ],
    ),
  );

  Widget _buildStepCircle(int index) {
    final isActive = index == _currentStep;
    final isDone = index < _currentStep;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDone || isActive) ? _primaryColor : Colors.grey[200],
            border: isActive
                ? Border.all(
                    color: _primaryColor.withOpacity(0.25),
                    width: 5,
                  )
                : null,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.white : Colors.grey[500],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stepTitles[index],
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            color: isActive ? _primaryColor : Colors.grey[400],
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildConnector(bool active) => Padding(
    padding: const EdgeInsets.only(bottom: 22),
    child: SizedBox(
      width: 28,
      child: Container(
        height: 2,
        color: active ? _primaryColor : Colors.grey[200],
      ),
    ),
  );

  Widget _buildStepIndicator() => Container(
    width: double.infinity,
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < _stepCount; i++) ...[
          _buildStepCircle(i),
          if (i != _stepCount - 1) _buildConnector(i < _currentStep),
        ],
      ],
    ),
  );

  Widget _buildStoreInfoStep() => Form(
    key: _formKeys[0],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildScreenHeader(
          "ข้อมูลร้านค้าของคุณ",
          "กรอกชื่อร้านและช่องทางติดต่อหลักให้ลูกค้าติดต่อได้",
        ),
        Center(
          child: Stack(
            children: [
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _pageBackground,
                  border: Border.all(color: _borderColor, width: 1.5),
                ),
                child: _logoImage != null
                    ? ClipOval(
                        child: Image.file(_logoImage!, fit: BoxFit.cover),
                      )
                    : Icon(
                        Icons.storefront_outlined,
                        size: 42,
                        color: Colors.grey[400],
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _showLogoPickerDialog,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primaryColor,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Text(
            'แตะไอคอนกล้องเพื่อเพิ่มโลโก้ร้าน',
            style: TextStyle(fontSize: 12, color: _mutedText),
          ),
        ),
        const SizedBox(height: 26),
        _buildSectionCard(
          title: "ข้อมูลพื้นฐาน",
          icon: Icons.badge_outlined,
          fields: [
            _buildTextField(
              controller: _storeNameController,
              label: "ชื่อร้านค้า *",
              icon: Icons.store_outlined,
              hint: "ร้านซักรีดดีไซน์",
              validator: _validateRequired,
            ),
            _buildTextField(
              controller: _phoneController,
              label: "เบอร์โทร *",
              icon: Icons.phone_outlined,
              hint: "0812345678",
              validator: _validatePhone,
              keyboardType: TextInputType.phone,
            ),
            _buildTextField(
              controller: _emailController,
              label: "อีเมล *",
              icon: Icons.email_outlined,
              hint: "store@example.com",
              validator: _validateEmail,
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        _buildSectionCard(
          title: "ช่องทางติดต่อเพิ่มเติม",
          icon: Icons.chat_bubble_outline,
          subtitle: "ไม่บังคับ — เพิ่มได้ภายหลัง",
          fields: [
            _buildTextField(
              controller: _facebookController,
              label: "Facebook",
              icon: Icons.facebook_outlined,
              hint: "facebook.com/yourpage",
              keyboardType: TextInputType.url,
            ),
            _buildTextField(
              controller: _lineIdController,
              label: "Line ID",
              icon: Icons.chat_outlined,
              hint: "@yourlineid",
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildLocationScheduleStep() => Form(
    key: _formKeys[1],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildScreenHeader(
          "ที่ตั้ง เวลาทำการ และค่าบริการ",
          "ข้อมูลนี้ช่วยให้ลูกค้ารู้ว่าร้านของคุณให้บริการเมื่อไหร่และที่ไหน",
        ),
        _buildSectionCard(
          title: "ที่อยู่ร้าน",
          icon: Icons.location_on_outlined,
          fields: [
            _buildTextField(
              controller: _addressController,
              label: "ที่อยู่ร้าน *",
              icon: Icons.home_outlined,
              hint: "บ้านเลขที่ ถนน ตำบล อำเภอ จังหวัด",
              validator: _validateRequired,
              maxLines: 3,
            ),
            OutlinedButton.icon(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MapPicker()),
                );
                if (result != null) {
                  _addressController.text = result["address"];
                }
              },
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text("เลือกตำแหน่งจากแผนที่"),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
                side: const BorderSide(color: _primaryColor),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            _buildTextField(
              controller: _serviceRadiusController,
              label: "รัศมีบริการ (กม.) *",
              icon: Icons.social_distance_outlined,
              hint: "5",
              validator: _validateNumber,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
        _buildSectionCard(
          title: "เวลาทำการ",
          icon: Icons.schedule_outlined,
          subtitle: "แตะเวลาแล้วเลื่อนขึ้นลงเพื่อเลือก",
          fields: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _openingTimeController,
                    label: "เวลาเปิด *",
                    icon: Icons.wb_sunny_outlined,
                    hint: "08:00",
                    validator: _validateTime,
                    readOnly: true,
                    onTap: () => _showTimeWheelPicker(
                      _openingTimeController,
                      "เลือกเวลาเปิด",
                    ),
                    suffixIcon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _mutedText,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _closingTimeController,
                    label: "เวลาปิด *",
                    icon: Icons.nights_stay_outlined,
                    hint: "18:00",
                    validator: _validateTime,
                    readOnly: true,
                    onTap: () => _showTimeWheelPicker(
                      _closingTimeController,
                      "เลือกเวลาปิด",
                    ),
                    suffixIcon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: _mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        _buildSectionCard(
          title: "ค่าบริการ",
          icon: Icons.payments_outlined,
          fields: [
            _sectionLabel("ค่าจัดส่ง (บาท)"),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _minDeliveryController,
                    label: "ต่ำสุด *",
                    icon: Icons.arrow_downward,
                    hint: "0",
                    validator: _validateNumber,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _maxDeliveryController,
                    label: "สูงสุด *",
                    icon: Icons.arrow_upward,
                    hint: "100",
                    validator: _validateMaxDelivery,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _sectionLabel("ค่าน้ำยาซักผ้า"),
            _buildTextField(
              controller: _detergentPriceController,
              label: "ราคาน้ำยาซักผ้า (บาท/ครั้ง) *",
              icon: Icons.local_laundry_service_outlined,
              hint: "20",
              validator: _validateNonNegativeNumber,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildAddAdImageTile() => GestureDetector(
    onTap: _showAdImagePickerDialog,
    child: DottedBox(
      child: Container(
        decoration: BoxDecoration(
          color: _lightBlueBackground.withOpacity(0.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: _primaryColor, size: 26),
              SizedBox(height: 6),
              Text(
                "เพิ่มรูป",
                style: TextStyle(
                  color: _primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildAdImagesStep() => Form(
    key: _formKeys[2],
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        _buildScreenHeader(
          "รูปโฆษณาร้านค้า",
          "เพิ่มรูปภาพที่จะช่วยดึงดูดลูกค้าให้เลือกร้านของคุณ (ไม่บังคับ)",
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _borderColor),
          ),
          child: Row(
            children: [
              const Icon(Icons.image_outlined, color: _primaryColor, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "รูปโฆษณาร้าน",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _lightBlueBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${_adImages.length}/5",
                  style: const TextStyle(
                    color: _primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: _adImages.length + (_adImages.length < 5 ? 1 : 0),
          itemBuilder: (_, index) {
            if (index == _adImages.length) return _buildAddAdImageTile();
            final file = _adImages[index];
            return Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: () => setState(() => _adImages.removeAt(index)),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: _dangerColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        if (_adImages.isEmpty) ...[
          const SizedBox(height: 20),
          Center(
            child: Text(
              "ยังไม่ต้องเพิ่มรูปก็ได้ ข้ามขั้นตอนนี้แล้วกดบันทึกได้เลย",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[400]),
            ),
          ),
        ],
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_apiEndpoint == null && _errorMessage == null) {
      return const Scaffold(
        backgroundColor: _pageBackground,
        body: Center(
          child: CircularProgressIndicator(color: _primaryColor),
        ),
      );
    }
    return Scaffold(
      backgroundColor: _pageBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0593FF),
                Color(0xFF0476D9),
              ],
            ),
          ),
        ),
        title: const Text(
          "ตั้งค่าร้านค้า",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildStepIndicator(),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDEDED),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _dangerColor.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: _dangerColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: _dangerColor, fontSize: 13),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _errorMessage = null),
                    child: const Icon(Icons.close, color: _dangerColor, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildStoreInfoStep(),
                _buildLocationScheduleStep(),
                _buildAdImagesStep(),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_currentStep > 0) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _goToPreviousStep,
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text("ย้อนกลับ"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: const BorderSide(color: _borderColor),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: _currentStep > 0 ? 2 : 1,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _goToNextStep,
                    icon: _isLoading
                        ? const SizedBox.shrink()
                        : Icon(
                            _currentStep < _stepCount - 1
                                ? Icons.arrow_forward
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                    label: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Text(
                            _currentStep < _stepCount - 1 ? "ถัดไป" : "บันทึก",
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DottedBox extends StatelessWidget {
  final Widget child;
  const DottedBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedBorderPainter(color: _primaryColor, radius: 14),
      child: child,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.7, 0.7, size.width - 1.4, size.height - 1.4),
      Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashGap = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}