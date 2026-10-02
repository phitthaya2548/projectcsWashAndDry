import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/customer/req_address_customer.dart';
import 'package:wash_and_dry/screens/pickaddress_frommap.dart';
import 'package:wash_and_dry/service/address_service.dart';

class CustomerAddressScreen extends StatefulWidget {
  final String customerId;

  const CustomerAddressScreen({super.key, required this.customerId});

  @override
  State<CustomerAddressScreen> createState() => _CustomerAddressScreenState();
}

class _CustomerAddressScreenState extends State<CustomerAddressScreen> {
  List<Address> addresses = [];
  String? url;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await Configuration.getConfig();
    url = config['apiEndpoint'];
    await loadAddresses();
  }

  Future<void> loadAddresses() async {
    final res = await http.get(
      Uri.parse("$url/customer/addresses/${widget.customerId}"),
    );
    final data = jsonDecode(res.body);
    setState(() {
      addresses =
          (data["data"] as List?)?.map((e) => Address.fromJson(e)).toList() ??
          [];
      loading = false;
    });
  }

  void _showSnack(String msg, bool success) {
    Get.snackbar(
      success ? "สำเร็จ" : "ผิดพลาด",
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: success ? Colors.green : Colors.red,
      colorText: Colors.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

 Future<void> addAddress({
  required String name,
  required String address,
  required bool isDefault,
}) async {
  try {
    final geo = await geocodeFromAddress(address);

    final res = await http.post(
      Uri.parse("$url/customer/addresses/${widget.customerId}"),
      headers: {"Content-Type": "application/json"},
      body: addressToJson(
        Address(
          addressName: name,
          addressText: address,
          latitude: geo.lat,
          longitude: geo.lng,
          status: isDefault,
        ),
      ),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      _showSnack("เพิ่มที่อยู่ไม่สำเร็จ", false);
      return;
    }

    final data = jsonDecode(res.body);

    if (data["ok"] == true) {
      await loadAddresses();
      _showSnack("เพิ่มที่อยู่สำเร็จ", true);
    } else {
      _showSnack(data["message"] ?? "เพิ่มไม่สำเร็จ", false);
    }

  } catch (e, s) {
    log("Add error: $e");
    log("Stacktrace: $s");
    _showSnack("เกิดข้อผิดพลาด", false);
  }
}


  Future<void> updateAddress({
    required String id,
    required String name,
    required String address,
    required bool isDefault,
  }) async {
    try {
      final geo = await geocodeFromAddress(address);

      final res = await http.put(
        Uri.parse("$url/customer/addresses/update/$id"),
        headers: {"Content-Type": "application/json"},
        body: addressToJson(
          Address(
            addressName: name,
            addressText: address,
            latitude: geo.lat,
            longitude: geo.lng,
            status: isDefault,
          ),
        ),
      );
      final data = jsonDecode(res.body);
      if (data["ok"] == false) {
        _showSnack("แก้ไขที่อยู่ไม่สำเร็จ", false);
        return;
      }
       
      if(data["ok"] == true) {
        await loadAddresses();
        _showSnack("แก้ไขที่อยู่สำเร็จ", true);
      } else {
        _showSnack(data["message"] ?? "แก้ไขไม่สำเร็จ", false);
      }
      
    } catch (e) {
      log("Update error: $e");
      _showSnack("ไม่สามารถแก้ไขได้", false);
    }
  }

Future<void> deleteAddress(String id) async {
  try {
    final res = await http.delete(
      Uri.parse("$url/customer/addresses/delete/$id"),
    );

    if (res.statusCode == 200) {
      await loadAddresses();
      _showSnack("ลบที่อยู่สำเร็จ", true);
    } else {
      log("Delete address failed: ${res.statusCode} ${res.body}");
      _showSnack("ไม่สามารถลบที่อยู่ได้", false);
    }
  } catch (e) {
    log("Delete error: $e");
    _showSnack("ไม่สามารถลบได้", false);
  }
}

void _deleteAddressNotification(String id) {
  Get.dialog(
    Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.delete_outline_rounded,
                color: Colors.red.shade400,
                size: 32,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'ยืนยันการลบ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ต้องการลบที่อยู่นี้ใช่หรือไม่?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Get.back();
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();
                      await deleteAddress(id);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'ยืนยัน',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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
    barrierDismissible: true,
  );
}

  Future<void> setDefault(String id) async {
    try {
      await http.put(
        Uri.parse("$url/customer/addresses/status/$id"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"status": true}),
      );
      await loadAddresses();
      _showSnack("ตั้งเป็นที่อยู่หลักแล้ว", true);
    } catch (e) {
      log("Set default error: $e");
    }
  }
  

  void showAddDialog() {
    _showAddressDialog(
      title: "เพิ่มที่อยู่",
      buttonText: "เพิ่ม",
      onSave: (name, address, isDefault) async {
        await addAddress(name: name, address: address, isDefault: isDefault);
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void showEditDialog(Address a) {
    _showAddressDialog(
      title: "แก้ไขที่อยู่",
      buttonText: "บันทึก",
      initialName: a.addressName,
      initialAddress: a.addressText,
      initialIsDefault: a.status,
      onSave: (name, address, isDefault) async {
        await updateAddress(
          id: a.id!,
          name: name,
          address: address,
          isDefault: isDefault,
        );
        if (mounted) Navigator.pop(context);
      },
    );
  }

  void _showAddressDialog({
    required String title,
    required String buttonText,
    String? initialName,
    String? initialAddress,
    bool initialIsDefault = true,
    required Function(String, String, bool) onSave,
  }) {
    final nameCtrl = TextEditingController(text: initialName);
    final addressCtrl = TextEditingController(text: initialAddress);
    bool isDefault = initialIsDefault;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (c, setS) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: nameCtrl,
                  label: "ชื่อที่อยู่",
                  hint: "เช่น บ้าน, ออฟฟิศ",
                  icon: Icons.label_outline,
                ),
                _buildTextField(
                  controller: addressCtrl,
                  label: "รายละเอียดที่อยู่",
                  hint: "ที่อยู่, ตำบล, อำเภอ, จังหวัด, รหัสไปรษณีย์",
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  icon: const Icon(Icons.map),
                  label: const Text("เลือกจากแผนที่"),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapPicker()),
                    );
                    if (result != null) addressCtrl.text = result["address"];
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "ตั้งเป็นที่อยู่หลัก",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Switch(
                        value: isDefault,
                        onChanged: (v) => setS(() => isDefault = v),
                        activeColor: Colors.blue,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () =>
                        onSave(nameCtrl.text, addressCtrl.text, isDefault),
                    child: Text(
                      buttonText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int? maxLines,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        maxLines: maxLines ?? 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: Colors.blue) : null,
          filled: true,
          fillColor: Colors.grey[50],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 2),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: const Text(
          "ที่อยู่ของฉัน",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
         onPressed: () => Get.back(result: true),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
          ? const Center(child: Text("ไม่มีที่อยู่"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: addresses.length,
              itemBuilder: (c, i) {
                final a = addresses[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Row(
                      children: [
                        Text(
                          a.addressName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (a.status) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              "หลัก",
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        a.addressText,
                        style: TextStyle(color: Colors.grey[700], fontSize: 14),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    trailing: PopupMenuButton(
                      icon: Icon(Icons.more_vert, color: Colors.grey[600]),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: "edit",
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: 12),
                              Text("แก้ไข"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: "default",
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, size: 20),
                              SizedBox(width: 12),
                              Text("ตั้งเป็นที่อยู่หลัก"),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: "delete",
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                              SizedBox(width: 12),
                              Text("ลบ", style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                      onSelected: (v) {
                        if (v == "edit")
                          showEditDialog(a);
                        else if (v == "default")
                          setDefault(a.id!);
                        else if (v == "delete")
                          _deleteAddressNotification(a.id!);
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddDialog,
        backgroundColor: const Color(0xFF0593FF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "เพิ่มที่อยู่",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
