import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:get/get.dart';
import 'package:get/get_connect/http/src/utils/utils.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/service/session_service.dart';

class TopupCustomer extends StatefulWidget {
  const TopupCustomer({super.key});
  @override
  State<TopupCustomer> createState() => _TopupCustomerState();
}

class _TopupCustomerState extends State<TopupCustomer> {
  final _picker = ImagePicker();
  final _session = Session();
  File? _slipFile;
  bool _loading = false;
  String url = '';

  @override
  void initState() {
    super.initState();
    loadConfig();
  }

  void loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      setState(() => url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {
      setState(() => url = '');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildQRSection(),
                  const SizedBox(height: 24),
                  _buildSlipSection(),
                  const SizedBox(height: 24),
                  _buildInfoBox(),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomButton(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      title: const Text(
        "เติมเงิน",
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildQRSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0593FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_2,
                  color: Color(0xFF0593FF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "สแกน QR Code",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                  color: Colors.blueGrey,
                ),
                onPressed: _saveQrToGallery,
                tooltip: "บันทึก QR Code",
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              "assets/images/qrcode.jpg",
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildQRPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQRPlaceholder() {
    return Container(
      height: 300,
      alignment: Alignment.center,
      color: const Color(0xFFF1F5F9),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            "ใส่รูป QR Code",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSlipSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "แนบสลิปการโอนเงิน",
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "อัปโหลดรูปสลิปเพื่อยืนยันการชำระเงิน",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSlipUploadArea(),
        ],
      ),
    );
  }

  Widget _buildSlipUploadArea() {
    return InkWell(
      onTap: _loading ? null : _pickSlip,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 140,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _slipFile != null
                ? const Color(0xFF0593FF)
                : const Color(0xFFCBD5E1),
            width: _slipFile != null ? 2 : 1,
          ),
          color: const Color(0xFFF8FAFC),
        ),
        child: _slipFile == null
            ? _buildUploadPlaceholder()
            : _buildSlipPreview(),
      ),
    );
  }

  Widget _buildUploadPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.cloud_upload_outlined,
          size: 48,
          color: _loading ? Colors.grey : const Color(0xFF64748B),
        ),
        const SizedBox(height: 12),
        Text(
          _loading ? "กำลังส่ง..." : "คลิกเพื่ออัปโหลดสลิป",
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSlipPreview() {
    return Stack(
      children: [
        InkWell(
          onTap: _loading ? null : () => _showFullScreenSlip(context),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              _slipFile!,
              fit: BoxFit.contain,
              width: double.infinity,
              height: 140,
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 8,
          child: InkWell(
            onTap: _loading ? null : _removeSlip,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.zoom_in, color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'แตะเพื่อดูเต็มจอ',
                  style: TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFullScreenSlip(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4,
                      child: Image.file(_slipFile!, fit: BoxFit.contain),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 12,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
          const SizedBox(width: 12),
          Text(
            "ระบบจะตรวจสอบและเติมเงินอัตโนมัติ",
            style: TextStyle(
              color: Colors.amber[900],
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: _loading ? null : _submitTopup,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _loading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline, size: 22),
                      SizedBox(width: 8),
                      Text(
                        "ยืนยันการเติมเงิน",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveQrToGallery() async {
    try {
      final byteData = await rootBundle.load("assets/images/qrcode.jpg");
      final bytes = byteData.buffer.asUint8List();
      await Gal.putImageBytes(bytes, name: "qrcode_topup");
      if (!mounted) return;
      _showMsg("บันทึก QR Code ลงเครื่องแล้ว");
    } catch (e) {
      if (!mounted) return;
      _showMsg("บันทึกไม่สำเร็จ: $e", isError: true);
    }
  }

  Future<void> _pickSlip() async {
    if (_loading) return;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _slipFile = File(picked.path));
  }

  void _removeSlip() {
    setState(() => _slipFile = null);
  }

  Future<void> _submitTopup() async {
    if (_loading) return;
    if (_slipFile == null) {
      _showMsg("กรุณาอัปโหลดสลิปก่อน", isError: true);
      return;
    }
    if (!await _slipFile!.exists()) {
      _showMsg("ไฟล์สลิปหาย กรุณาเลือกใหม่", isError: true);
      _removeSlip();
      return;
    }
    setState(() => _loading = true);
    try {
      final customerId = await _session.getCustomerId();
      if (customerId == null || customerId.isEmpty) {
        _showMsg("ไม่พบข้อมูล Customer ID กรุณาเข้าสู่ระบบใหม่", isError: true);
        setState(() => _loading = false);
        return;
      }
      final request = http.MultipartRequest(
        "POST",
        Uri.parse(url + "/wallet/checkslip"),
      );
      request.fields['customer_id'] = customerId;
      final mimeType = lookupMimeType(_slipFile!.path) ?? "image/jpeg";
      final parts = mimeType.split('/');
      request.files.add(
        await http.MultipartFile.fromPath(
          "file",
          _slipFile!.path,
          contentType: MediaType(
            parts[0],
            parts.length > 1 ? parts[1] : "jpeg",
          ),
        ),
      );
      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (!mounted) return;
      Map<String, dynamic> data = {};
      try {
        data = json.decode(body);
      } catch (_) {}
      if (data["ok"] == true) {
        _showSuccess();
      } else {
        final message = data["message"]?.toString() ?? "ตรวจสลิปไม่สำเร็จ";
        _showMsg(message, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMsg("เกิดข้อผิดพลาด: $e", isError: true);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

void _showMsg(String text, {bool isError = false}) {
  Get.snackbar(
    isError ? "เกิดข้อผิดพลาด" : "แจ้งเตือน",
    text,
    snackPosition: SnackPosition.TOP,
    backgroundColor: isError ? Colors.red[600] : Color(0xFF22C55E),
    colorText: Colors.white,
    icon: Icon(isError ? Icons.error_outline : Icons.info_outline, color: Colors.white),
    margin: const EdgeInsets.all(16),
    borderRadius: 10,
    duration: const Duration(seconds: 3),
    snackStyle: SnackStyle.FLOATING,
    boxShadows: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4))],
    animationDuration: const Duration(milliseconds: 300),
  );
}

  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF22C55E),
                  size: 64,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "เติมเงินสำเร็จ!",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "ยอดเงินของคุณได้รับการอัปเดตแล้ว",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Get.back(result: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0593FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "กลับหน้าวอลเล็ต",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
