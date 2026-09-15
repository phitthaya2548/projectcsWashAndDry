import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/customer/req_address_customer.dart';
import 'package:wash_and_dry/models/req/customer/req_order_customer.dart';
import 'package:wash_and_dry/screens/customer/customer_address_screen.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_orderslist_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/main_shell_customer.dart';

class CustomerOrderScreen extends StatefulWidget {
  final String storeId;
  const CustomerOrderScreen({super.key, required this.storeId});
  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF0EA5E9);
  static const _dark = Color(0xFF0F172A);

  String url = '';
  String? customerId;
  String? addressId;
  String? selectedService;
  String? selectedDetergent;
  bool loading = true;
  bool isSubmitting = false;
  List<Address> addresses = [];
  final _noteCtrl = TextEditingController();
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _anim.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      await _loadAddress();
      _anim.forward();
    } catch (_) {
      setState(() => loading = false);
    }
  }

  Future<void> _loadAddress() async {
    setState(() => loading = true);
    customerId ??= await Session().getCustomerId();
    try {
      final res = await http.get(
        Uri.parse('$url/customer/addresses/active/$customerId'),
      );
      final body = jsonDecode(res.body);
      log(body.toString());
      setState(() {
        addressId = body['data']?['address_id'];
        addresses = body['data'] != null
            ? [Address.fromJson(body['data'])]
            : [];
        loading = false;
      });
    } catch (_) {
      setState(() {
        addresses = [];
        loading = false;
      });
    }
  }

  void _onConfirm() {
    if (selectedService == null) return _err('กรุณาเลือกประเภทบริการ');
    if (selectedDetergent == null) return _err('กรุณาเลือกตัวเลือกน้ำยาซักผ้า');
    if (addresses.isEmpty) return _err('กรุณาเพิ่มที่อยู่จัดส่งก่อน');
    _showConfirmDialog();
  }

  void _err(String msg) => Get.snackbar(
    '',
    msg,
    titleText: const SizedBox.shrink(),
    messageText: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
        const SizedBox(width: 8),
        Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
    ),
    snackPosition: SnackPosition.BOTTOM,
    backgroundColor: const Color(0xFFEF4444),
    borderRadius: 14,
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 2),
  );

  Future<void> _submit() async {
    setState(() => isSubmitting = true);
    try {
      final res = await http.post(
        Uri.parse('$url/order/create'),
        headers: {'Content-Type': 'application/json'},
        body: reqCreateOrderToJson(
          ReqCreateOrder(
            customerId: customerId!,
            storeId: widget.storeId,
            serviceType: selectedService!,
            washDryWeigh: 0,
            totalAmount: 0,
            addressId: addressId,
            detergentOption: selectedDetergent,
            note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
          ),
        ),
      );
      final data = resCreateOrderFromJson(res.body);
      Navigator.pop(context);

      if (data.ok == true) {
        setState(() {
          selectedService = null;
          selectedDetergent = null;
          addressId = null;
          addresses = [];
        });
        _noteCtrl.clear();
        await _loadAddress();

        Get.snackbar(
          'สั่งบริการสำเร็จ!',
          'รอร้านค้ารับออเดอร์',
          titleText: const Text(
            'สั่งบริการสำเร็จ!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          messageText: const Text(
            'รอร้านค้ารับออเดอร์',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          snackPosition: SnackPosition.TOP,
          backgroundColor: const Color(0xFF22C55E),
          borderRadius: 16,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          duration: const Duration(seconds: 3),
          icon: const Icon(
            Icons.check_circle_rounded,
            color: Colors.white,
            size: 28,
          ),
          shouldIconPulse: false,
        );
        await Future.delayed(const Duration(seconds: 1));
       
Get.offAll(
  () => const MainShellCustomer(initialIndex: 1),
);
      } else {
        _err(data.message);
      }
    } catch (_) {
      Navigator.pop(context);
      _err('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  void _showConfirmDialog() {
    final svcLabel = {
      'wash': 'บริการซักผ้า',
      'dry': 'บริการอบผ้า',
      'wash_dry': 'บริการซักและอบผ้า',
    }[selectedService]!;
    final detLabel = selectedDetergent == 'detergent'
        ? 'มีน้ำยาซักมาเอง'
        : 'ไม่มีน้ำยาซัก';

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0EA5E9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.local_laundry_service_rounded,
                      color: Colors.white,
                      size: 34,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ยืนยันคำสั่งซัก',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _dRow('บริการ', svcLabel),
                    const Divider(height: 20),
                    _dRow( 'น้ำยาซัก', detLabel),
                    const Divider(height: 20),
                    _dRow(
                      'ที่อยู่',
                      addresses.first.addressName,
                    ),
                    if (_noteCtrl.text.isNotEmpty) ...[
                      const Divider(height: 20),
                      _dRow('หมายเหตุ', _noteCtrl.text),
                    ],
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black54,
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'ยกเลิก',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'ยืนยัน',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dRow(String label, String value) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.black45),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _dark,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        flexibleSpace: Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
        ),
      ),
    ),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.white,
          ),
          onPressed: Get.back,
        ),
        title: const Text(
          'บริการซักผ้า',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(parent: _anim, curve: Curves.easeOut),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
          children: [
            _sectionLabel('เลือกบริการ'),
            const SizedBox(height: 10),
            _serviceCard(),
            const SizedBox(height: 20),
            _sectionLabel('น้ำยาซักผ้า'),
            const SizedBox(height: 10),
            _detergentCard(),
            const SizedBox(height: 20),
            _sectionLabel('หมายเหตุ'),
            const SizedBox(height: 10),
            _noteCard(),
            const SizedBox(height: 20),
            _sectionLabel('ที่อยู่จัดส่ง'),
            const SizedBox(height: 10),
            _addressCard(),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.black.withOpacity(0.06)),
          ),
        ),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          onPressed: _onConfirm,
          icon: const Icon(Icons.check_rounded, size: 20),
          label: const Text(
            'ยืนยันคำสั่งซัก',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Colors.black45,
      letterSpacing: 0.8,
    ),
  );

  BoxDecoration _cardDecor() => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.04),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  Widget _serviceCard() {
  final _services = [
    ('wash',     'ซักอย่างเดียว'),
    ('dry',      'อบอย่างเดียว'),
    ('wash_dry', 'ซักและอบ'),
  ];

  return Container(
    decoration: _cardDecor(),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icons/machine.png', width: 24, height: 24),
              const SizedBox(width: 8),
              const Text(
                'บริการซักผ้า',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: _dark,
                ),
              ),
              const SizedBox(width: 8),
              Image.asset('assets/icons/machine.png', width: 24, height: 24),
            ],
          ),
        ),
        const Divider(height: 1),
        ..._services.asMap().entries.map((e) {
          final (value, title) = e.value;
          final sel = selectedService == value;
          final last = e.key == _services.length - 1;
          return Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.vertical(
                  bottom: last ? const Radius.circular(16) : Radius.zero,
                ),
                onTap: () => setState(() => selectedService = value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: sel
                        ? _primary.withOpacity(0.06)
                        : Colors.transparent,
                    borderRadius: BorderRadius.vertical(
                      bottom: last ? const Radius.circular(16) : Radius.zero,
                    ),
                  ),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: sel ? _primary : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        // ✅ ไอคอนเดียวทุก row
                        child: Icon(
                          Icons.local_laundry_service,
                          size: 17,
                          color: sel ? Colors.white : Colors.black45,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: sel ? _primary : _dark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? _primary : const Color(0xFFCBD5E1),
                            width: 2,
                          ),
                          color: sel ? _primary : Colors.transparent,
                        ),
                        child: sel
                            ? const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              if (!last) const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
      ],
    ),
  );
}

  Widget _detergentCard() {
    return Container(
      decoration: _cardDecor(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/icons/detergent.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  'น้ำยาซักผ้า',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: _dark,
                  ),
                ),
                const SizedBox(width: 8),
                Image.asset(
                  'assets/icons/detergent.png',
                  width: 24,
                  height: 24,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _detTile(
                    'detergent',
                    'มีน้ำยาเอง',
                    Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _detTile(
                    'no_detergent',
                    'ไม่มีน้ำยา',
                    Icons.remove_circle_outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detTile(String val, String label, IconData icon) {
    final sel = selectedDetergent == val;
    return GestureDetector(
      onTap: () => setState(() => selectedDetergent = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: sel ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? _primary : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: sel
                  ? _primary.withOpacity(0.2)
                  : Colors.black.withOpacity(0.03),
              blurRadius: sel ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: sel ? Colors.white : Colors.black38),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: sel ? Colors.white : _dark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _noteCard() => Container(
    decoration: _cardDecor(),
    child: TextField(
      controller: _noteCtrl,
      maxLines: 3,
      style: const TextStyle(fontSize: 14, color: _dark),
      decoration: InputDecoration(
        hintText: 'เพิ่มหมายเหตุ...',
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 14, right: 10, top: 14),
          child: Icon(Icons.note_alt_outlined, color: Colors.black38, size: 19),
        ),
        prefixIconConstraints: const BoxConstraints(),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
      ),
    ),
  );

  Widget _addressCard() => GestureDetector(
    onTap: () async {
      if (customerId == null) return;
      await Get.to(() => CustomerAddressScreen(customerId: customerId!));
      await _loadAddress();
    },
    child: Container(
      decoration: _cardDecor(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: Colors.red.shade400,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: loading
                ? const Text(
                    'กำลังโหลด...',
                    style: TextStyle(fontSize: 13, color: Colors.black45),
                  )
                : addresses.isEmpty
                ? const Text(
                    'ยังไม่มีที่อยู่ กรุณาเพิ่มที่อยู่',
                    style: TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        addresses.first.addressName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: _dark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        addresses.first.addressText,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black45,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: Colors.black26,
            size: 20,
          ),
        ],
      ),
    ),
  );
}
