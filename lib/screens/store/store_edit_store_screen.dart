import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_edit_store.dart';

import 'package:wash_and_dry/models/res/customer/store/res_profile_store.dart';
import 'package:wash_and_dry/screens/pickaddress_frommap.dart';
const _blue = Color(0xFF0593FF);
const _blueDark = Color(0xFF0476D9);
const _dark = Color(0xFF1A1A2E);
const _red = Color(0xFFE53935);
const _bg = Color(0xFFF0F4F8);

class StoreEditScreen extends StatefulWidget {
  final String storeId;
  const StoreEditScreen({super.key, required this.storeId});

  @override
  State<StoreEditScreen> createState() => _StoreEditScreenState();
}

class _StoreEditScreenState extends State<StoreEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _facebookCtrl = TextEditingController();
  final _lineCtrl = TextEditingController();
  final _deliveryMinCtrl = TextEditingController();
  final _deliveryMaxCtrl = TextEditingController();
  final _radiusCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _detergentPriceCtrl = TextEditingController();

  String? _profileImageUrl;
  File? _newProfileImage;
  List<Map<String, String>> _savedImages = [];
  List<File> _pendingImages = [];
  double? _lat, _lng;
  bool _loading = true;
  bool _saving = false;
  String _apiUrl = '';


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _addressCtrl,
      _phoneCtrl,
      _emailCtrl,
      _facebookCtrl,
      _lineCtrl,
      _deliveryMinCtrl,
      _deliveryMaxCtrl,
      _radiusCtrl,
      _openCtrl,
      _closeCtrl,
      _detergentPriceCtrl,
    ])
      c.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final cfg = await Configuration.getConfig();
      _apiUrl = cfg['apiEndpoint']?.toString() ?? '';
      await Future.wait([_loadProfile(), _loadGallery()]);
    } catch (e) {
      log('LOAD ERROR: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
  final res = await http.get(
    Uri.parse('$_apiUrl/store/profile/${widget.storeId}'),
  );
  if (res.statusCode != 200) return;

  final raw = jsonDecode(res.body) as Map<String, dynamic>;
  final srcMap = raw['data'] is Map
      ? raw['data'] as Map<String, dynamic>
      : raw;
  final d = StoreData.fromJson(srcMap);

  setState(() {
    _nameCtrl.text = d.storeName;
    _addressCtrl.text = d.address;
    _phoneCtrl.text = d.phone;
    _emailCtrl.text = d.email;
    _facebookCtrl.text = d.facebook;
    _lineCtrl.text = d.lineId;
    _openCtrl.text = d.openingHours.isNotEmpty ? d.openingHours : '08:00';
    _closeCtrl.text = d.closedHours.isNotEmpty ? d.closedHours : '20:00';
    _deliveryMinCtrl.text = d.deliveryMin != 0
        ? d.deliveryMin.toStringAsFixed(0)
        : '';
    _deliveryMaxCtrl.text = d.deliveryMax != 0
        ? d.deliveryMax.toStringAsFixed(0)
        : '';
    _radiusCtrl.text = d.serviceRadius.toString();
    _profileImageUrl = d.profileImage;
    _lat = d.latitude != 0 ? d.latitude : null;
    _lng = d.longitude != 0 ? d.longitude : null;

    _detergentPriceCtrl.text = d.detergentPrice != 0
        ? d.detergentPrice.toStringAsFixed(0)
        : '';
  });
}
  Future<void> _loadGallery() async {
    final res = await http.get(
      Uri.parse('$_apiUrl/store/images/${widget.storeId}'),
    );
    if (res.statusCode != 200) return;

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final apiRes = ApiResponseModel.fromJson(body);
    if (!apiRes.ok) return;

    setState(() {
      _savedImages = (body['images'] as List)
          .map(
            (e) => {
              'image_id': e['image_id']?.toString() ?? '',
              'image_path': e['image_path']?.toString() ?? '',
            },
          )
          .where((m) => m['image_path']!.isNotEmpty)
          .toList();
    });
  }



  Future<File?> _pickImage() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.camera_alt, color: _blue, size: 20),
              ),
              title: const Text('ถ่ายภาพ'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.photo_library, color: _blue, size: 20),
              ),
              title: const Text('เลือกจากแกลอลี่'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (src == null) return null;
    final p = await _picker.pickImage(source: src, imageQuality: 85);
    return p != null ? File(p.path) : null;
  }


Future<void> _addGalleryPhoto() async {
  final remaining = 5 - (_savedImages.length + _pendingImages.length);

  if (remaining <= 0) {
    _snack('เพิ่มได้ไม่เกิน 5 รูป', isError: true);
    return;
  }

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.camera_alt,
                color: _blue,
                size: 20,
              ),
            ),
            title: const Text('ถ่ายภาพ'),
            onTap: () {
              Navigator.of(sheetContext).pop(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFE3F2FD),
              child: Icon(
                Icons.photo_library,
                color: _blue,
                size: 20,
              ),
            ),
            title: const Text('เลือกแกลเลอลี่'),
            onTap: () {
              Navigator.of(sheetContext).pop(ImageSource.gallery);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );

  if (!mounted || source == null) return;

  if (source == ImageSource.camera) {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (!mounted || picked == null) return;

    setState(() {
      _pendingImages.add(File(picked.path));
    });

    return;
  }

  final picked = await _picker.pickMultiImage(
    imageQuality: 85,
  );

  if (!mounted || picked.isEmpty) return;

  final files = picked
      .take(remaining)
      .map((e) => File(e.path))
      .toList();

  setState(() {
    _pendingImages.addAll(files);
  });

  if (picked.length > remaining && mounted) {
    _snack(
      'เลือกได้สูงสุด 5 รูป ระบบเพิ่มให้ $remaining รูป',
      isError: true,
    );
  }
}

  Future<void> _replaceGalleryPhoto(int i) async {
    final f = await _pickImage();
    if (f == null) return;
    final id = _savedImages[i]['image_id']!;
    setState(() => _saving = true);
    try {
      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('$_apiUrl/store/images/$id'),
      )..files.add(await http.MultipartFile.fromPath('store_images', f.path));
      final res = await http.Response.fromStream(await req.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final apiRes = ApiResponseModel.fromJson(body);

      if (res.statusCode == 200 && apiRes.ok) {
        setState(
          () => _savedImages[i] = {
            'image_id': id,
            'image_path': body['image']['image_path'],
          },
        );
        _snack('เปลี่ยนรูปสำเร็จ');
      } else {
        _snack(apiRes.message ?? 'เกิดข้อผิดพลาด', isError: true);
      }
    } catch (e) {
      _snack('เชื่อมต่อไม่ได้', isError: true);
    }
    setState(() => _saving = false);
  }

  Future<void> _deleteGalleryPhoto(int i) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลบรูปภาพ'),
        content: const Text('ต้องการลบรูปนี้ใช่ไหม?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ลบ', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _saving = true);
    try {
      final res = await http.delete(
        Uri.parse('$_apiUrl/store/images/${_savedImages[i]['image_id']}'),
      );
      if (res.statusCode == 200) {
        setState(() => _savedImages.removeAt(i));
        _snack('ลบรูปสำเร็จ');
      } else {
        _snack('ลบรูปไม่สำเร็จ', isError: true);
      }
    } catch (_) {
      _snack('เชื่อมต่อไม่ได้', isError: true);
    }
    setState(() => _saving = false);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final profile = StoreProfileModel(
        storeName: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        serviceRadius: double.tryParse(_radiusCtrl.text.trim()) ?? 0,
        openingHours: _openCtrl.text.trim(),
        closingHours: _closeCtrl.text.trim(),
        deliveryMin: double.tryParse(_deliveryMinCtrl.text.trim()) ?? 0,
        deliveryMax: double.tryParse(_deliveryMaxCtrl.text.trim()) ?? 0,
        detergentPrice: double.tryParse(_detergentPriceCtrl.text.trim()) ?? 0,
        facebook: _facebookCtrl.text.trim(),
        lineId: _lineCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
      );

      final req = http.MultipartRequest(
        'PUT',
        Uri.parse('$_apiUrl/store/profile/${widget.storeId}'),
      )..fields.addAll(profile.toFormFields());

      if (_newProfileImage != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'profile_image',
            _newProfileImage!.path,
          ),
        );
      }

      final res = await http.Response.fromStream(await req.send());
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final apiRes = ApiResponseModel.fromJson(body);

      if (res.statusCode != 200 || !apiRes.ok) {
        _snack(apiRes.message ?? 'บันทึกไม่สำเร็จ', isError: true);
        setState(() => _saving = false);
        return;
      }

      if (_pendingImages.isNotEmpty) {
        final imgReq = http.MultipartRequest(
          'POST',
          Uri.parse('$_apiUrl/store/images/${widget.storeId}'),
        );
        for (final f in _pendingImages) {
          imgReq.files.add(
            await http.MultipartFile.fromPath('store_images', f.path),
          );
        }
        final imgRes = await http.Response.fromStream(await imgReq.send());
        final imgBody = jsonDecode(imgRes.body) as Map<String, dynamic>;
        final imgApiRes = ApiResponseModel.fromJson(imgBody);

        if (imgRes.statusCode == 200 && imgApiRes.ok) {
          setState(() {
            for (final img in imgBody['images'] as List) {
              _savedImages.add({
                'image_id': img['image_id']?.toString() ?? '',
                'image_path': img['image_path']?.toString() ?? '',
              });
            }
            _pendingImages.clear();
          });
        } else {
          _snack(imgApiRes.message ?? 'อัปโหลดรูปไม่สำเร็จ', isError: true);
          setState(() => _saving = false);
          return;
        }
      }

      setState(() => _saving = false);
      _snack('บันทึกสำเร็จ');
      await Future.delayed(const Duration(milliseconds: 800));
      Navigator.of(context).pop(true);
      return;
    } catch (e) {
      log('SAVE ERROR: $e');
      _snack('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้', isError: true);
      setState(() => _saving = false);
    }
  }

  void _snack(String msg, {bool isError = false}) => Get.snackbar(
    isError ? 'เกิดข้อผิดพลาด' : 'สำเร็จ',
    msg,
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: isError ? _red : const Color(0xFF43A047),
    colorText: Colors.white,
    borderRadius: 12,
    margin: const EdgeInsets.all(12),
    duration: const Duration(seconds: 3),
    icon: Icon(
      isError ? Icons.error_outline : Icons.check_circle_outline,
      color: Colors.white,
    ),
  );

  bool _isValidTime(String v) =>
      RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').hasMatch(v);


  Future<void> _pickTimeWheel(
    TextEditingController controller,
    String title,
  ) async {
    final parts = controller.text.split(':');
    final now = DateTime.now();

    int selectedHour = parts.length == 2
        ? int.tryParse(parts[0]) ?? now.hour
        : now.hour;
    int selectedMinute = parts.length == 2
        ? int.tryParse(parts[1]) ?? now.minute
        : now.minute;

    if (selectedHour < 0 || selectedHour > 23) {
      selectedHour = now.hour;
    }

    if (selectedMinute < 0 || selectedMinute > 59) {
      selectedMinute = now.minute;
    }

    final hourController = FixedExtentScrollController(
      initialItem: selectedHour,
    );
    final minuteController = FixedExtentScrollController(
      initialItem: selectedMinute,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final timeText =
                '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';

            return SafeArea(
              top: false,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7DCE2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.access_time_rounded,
                              color: _blue,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  timeText,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: _blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    SizedBox(
                      height: 220,
                      child: Row(
                        children: [
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: hourController,
                              itemExtent: 48,
                              diameterRatio: 1.2,
                              magnification: 1.08,
                              useMagnifier: true,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(
                                background: Color(0x140593FF),
                              ),
                              onSelectedItemChanged: (value) {
                                setSheetState(() {
                                  selectedHour = value;
                                });
                              },
                              children: List.generate(
                                24,
                                (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: _dark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const Text(
                            ':',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                          Expanded(
                            child: CupertinoPicker(
                              scrollController: minuteController,
                              itemExtent: 48,
                              diameterRatio: 1.2,
                              magnification: 1.08,
                              useMagnifier: true,
                              selectionOverlay:
                                  const CupertinoPickerDefaultSelectionOverlay(
                                background: Color(0x140593FF),
                              ),
                              onSelectedItemChanged: (value) {
                                setSheetState(() {
                                  selectedMinute = value;
                                });
                              },
                              children: List.generate(
                                60,
                                (index) => Center(
                                  child: Text(
                                    index.toString().padLeft(2, '0'),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                      color: _dark,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black54,
                                side: const BorderSide(
                                  color: Color(0xFFDDE3EA),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'ยกเลิก',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                controller.text =
                                    '${selectedHour.toString().padLeft(2, '0')}:${selectedMinute.toString().padLeft(2, '0')}';
                                Navigator.pop(sheetContext);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'ตกลง',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
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
            );
          },
        );
      },
    );

    hourController.dispose();
    minuteController.dispose();
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_blue, _blueDark],
            ),
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: Get.back,
        ),
        title: const Text(
          'ข้อมูลร้านค้า',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _blue))
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/name_store.png',
                      'ชื่อร้านค้า',
                      _buildNameSection(),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/localtion_store.png',
                      'ที่อยู่ร้านค้า',
                      _buildAddressSection(),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/contact_store.png',
                      'ข้อมูลติดต่อ',
                      _buildContactSection(),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/cloack_store.png',
                      'เวลาเปิด - ปิดร้านค้า',
                      _buildTimeSection(),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/radain_store.png',
                      'ค่าส่งและรัศมีให้บริการ',
                      _buildDeliverySection(),
                    ),
                    const SizedBox(height: 12),
                    _card(
                      'assets/icons/picture_store.png',
                      'รูปโชว์ร้าน (ไม่เกิน 5 รูป)',
                      _buildGallerySection(),
                    ),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }



  Widget _buildProfileHeader() {
    Widget profileImage() {
      if (_newProfileImage != null)
        return Image.file(_newProfileImage!, fit: BoxFit.cover);
      if (_profileImageUrl?.isNotEmpty == true) {
        return CachedNetworkImage(
          imageUrl: _profileImageUrl!,
          fit: BoxFit.cover,
          placeholder: (_, __) =>
              const Center(child: CircularProgressIndicator(color: _blue)),
          errorWidget: (_, __, ___) =>
              const Icon(Icons.store, size: 50, color: _blue),
        );
      }
      return const Icon(Icons.store, size: 50, color: _blue);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final f = await _pickImage();
              if (f != null) setState(() => _newProfileImage = f);
            },
            child: Stack(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _blue, width: 3),
                    color: const Color(0xFFE3F2FD),
                  ),
                  child: ClipOval(child: profileImage()),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: _blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _nameCtrl.text.isEmpty ? 'ชื่อร้านค้า' : _nameCtrl.text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label('ชื่อร้านค้า'),
      _field(
        controller: _nameCtrl,
        hint: 'กรอกชื่อร้านค้า',
        validator: (v) => v!.trim().isEmpty ? 'กรุณากรอกชื่อร้านค้า' : null,
      ),
    ],
  );

  Widget _buildAddressSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label('ที่อยู่'),
      _field(controller: _addressCtrl, hint: 'ที่อยู่', maxLines: 2),
      const SizedBox(height: 8),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.map_outlined, size: 18, color: _blue),
          label: Text(
            (_lat != null && _lng != null)
                ? 'ตำแหน่ง: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}'
                : 'เลือกจากแผนที่',
            style: const TextStyle(color: _blue, fontSize: 13),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: _blue),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          ),
          onPressed: () async {
  final r = await Navigator.push<Map<String, dynamic>>(
    context,
    MaterialPageRoute(builder: (_) => const MapPicker()),
  );
  if (r != null) {
    setState(() {
      _addressCtrl.text = r['address']?.toString() ?? '';
      final lat = r['lat'];
      final lng = r['lng'];
      _lat = lat is num ? lat.toDouble() : null;
      _lng = lng is num ? lng.toDouble() : null;
    });
  }
},
        ),
      ),
    ],
  );

  Widget _buildContactSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label('เบอร์โทร'),
      _field(
        controller: _phoneCtrl,
        hint: 'เบอร์โทรติดต่อ',
        keyboardType: TextInputType.phone,
      ),
      const SizedBox(height: 10),
      _label('อีเมล'),
      _field(
        controller: _emailCtrl,
        hint: 'อีเมลร้านค้า',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 10),
      _label('Facebook'),
      _field(controller: _facebookCtrl, hint: 'ชื่อ Facebook ร้านค้า'),
      const SizedBox(height: 10),
      _label('Line'),
      _field(controller: _lineCtrl, hint: 'ชื่อ Line ร้านค้า'),
    ],
  );

  Widget _buildTimeSection() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _timeField(_openCtrl, 'เวลาเปิด')),
      const Padding(
        padding: EdgeInsets.only(top: 28, left: 8, right: 8),
        child: Text(
          'ถึง',
          style: TextStyle(color: Colors.black54, fontSize: 14),
        ),
      ),
      Expanded(child: _timeField(_closeCtrl, 'เวลาปิด')),
    ],
  );

  Widget _buildDeliverySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('ค่าส่งต่ำสุด (บาท)'),
                _field(
                  controller: _deliveryMinCtrl,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('ค่าส่งสูงสุด (บาท)'),
                _field(
                  controller: _deliveryMaxCtrl,
                  hint: '0',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      _label('รัศมีให้บริการ (กม.)'),
      _field(
        controller: _radiusCtrl,
        hint: '0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
        ],
      ),
      const SizedBox(height: 12),
      _label('ราคาน้ำยาซักผ้า (บาท)'),
      _field(
        controller: _detergentPriceCtrl,
        hint: '0',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d*')),
        ],
        validator: (v) {
          if (v == null || v.trim().isEmpty) return 'กรุณากรอกราคาน้ำยาซักผ้า';
          if (double.tryParse(v.trim()) == null) return 'กรุณากรอกตัวเลข';
          return null;
        },
      ),
    ],
  );

  Widget _buildGallerySection() {
    final total = _savedImages.length + _pendingImages.length;

    Widget imageWithDelete(
      Widget img,
      VoidCallback onDelete, {
      VoidCallback? onTap,
    }) => Stack(
      children: [
        GestureDetector(
          onTap: onTap,
          child: ClipRRect(borderRadius: BorderRadius.circular(10), child: img),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: _red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );

    Widget imageRow(int count, Widget Function(int) builder) => SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => builder(i),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: _addGalleryPhoto,
          child: Container(
            width: double.infinity,
            height: 90,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.shade50,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 34,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 4),
                Text(
                  'เพิ่มรูปภาพ ($total/5)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        if (_savedImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          imageRow(
            _savedImages.length,
            (i) => imageWithDelete(
              CachedNetworkImage(
                imageUrl: _savedImages[i]['image_path']!,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _blue,
                    ),
                  ),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              () => _deleteGalleryPhoto(i),
              onTap: () => _replaceGalleryPhoto(i),
            ),
          ),
        ],
        if (_pendingImages.isNotEmpty) ...[
          const SizedBox(height: 12),
          imageRow(
            _pendingImages.length,
            (i) => imageWithDelete(
              Image.file(
                _pendingImages[i],
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
              () => setState(() => _pendingImages.removeAt(i)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSaveButton() => SizedBox(
    width: double.infinity,
    height: 52,
    child: ElevatedButton(
      onPressed: _saving ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: _blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: _saving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2.5,
              ),
            )
          : const Text(
              'บันทึกข้อมูล',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
    ),
  );


  Widget _card(String iconAsset, String title, Widget content) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_blue, _blueDark],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 16, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.all(7),
                          child: Image.asset(
                            iconAsset,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: _blue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _blueDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    content,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: const Color(0xFFFAFAFA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _blue, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _red, width: 1.2),
      ),
    ),
  );

  Widget _timeField(TextEditingController ctrl, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _label(label),
      TextFormField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickTimeWheel(ctrl, label),
        validator: (v) {
          if (v == null || v.isEmpty) return 'กรุณาเลือกเวลา';
          if (!_isValidTime(v)) return 'รูปแบบ HH:MM';
          return null;
        },
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: 'เลือกเวลา',
          hintStyle: const TextStyle(
            color: Color(0xFFBDBDBD),
            fontSize: 14,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 11,
          ),
          filled: true,
          fillColor: const Color(0xFFFAFAFA),
          suffixIcon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 22,
            color: _blue,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _blue, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: _red, width: 1.2),
          ),
        ),
      ),
    ],
  );

}
