import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_add_machine_store.dart';
import 'package:wash_and_dry/models/req/store/req_update_machine_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_machine_store.dart';
import 'package:wash_and_dry/service/session_service.dart';

class ManageMachineScreen extends StatefulWidget {
  const ManageMachineScreen({Key? key}) : super(key: key);

  @override
  State<ManageMachineScreen> createState() => _ManageMachineScreenState();
}

class _ManageMachineScreenState extends State<ManageMachineScreen> {
  String url = '';
  bool _isLoading = true;
  List<Machine> washers = [], dryers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final config = await Configuration.getConfig();
      final storeId = await Session().getStoreId();

      if (storeId == null) {
        _showSnackbar('ไม่พบข้อมูล Store ID', false);
        return;
      }

      url = config['apiEndpoint']?.toString() ?? '';
      await _loadMachines(storeId);
    } catch (e) {
      _showSnackbar('โหลดข้อมูลไม่สำเร็จ', false);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMachines(String storeId) async {
    try {
      final res = await http.get(Uri.parse('$url/store/machines/$storeId'));

      if (res.statusCode == 200) {
        final list = MachineListResponse.fromJson(json.decode(res.body));
        if (list.ok) {
          setState(() {
            washers = list.data.where((m) => m.type == 'washer').toList();
            dryers = list.data.where((m) => m.type == 'dryer').toList();
          });
        } else {
          _showSnackbar('ไม่สามารถโหลดรายการเครื่องได้', false);
        }
      } else {
        _showSnackbar('โหลดรายการเครื่องไม่สำเร็จ', false);
      }
    } catch (e) {
      _showSnackbar('เกิดข้อผิดพลาดในการโหลดข้อมูล', false);
    }
  }

  Future<void> _submitMachine({
    required String name,
    required String type,
    required int capacity,
    required double price,
    required int workMinutes,
  }) async {
    try {
      final storeId = await Session().getStoreId();
      if (storeId == null) {
        _showSnackbar('ไม่พบข้อมูล Store ID', false);
        return;
      }

      final res = await http.post(
        Uri.parse('$url/store/machine'),
        headers: {'Content-Type': 'application/json'},
        body: machineRequestToJson(
          MachineRequest(
            storeId: storeId,
            name: name,
            type: type,
            capacity: capacity,
            price: price,
            workMinutes: workMinutes,
          ),
        ),
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['ok'] == true) {
        Get.back();
        _showSnackbar(data['message'] ?? 'เพิ่มเครื่องสำเร็จ', true);
        await _loadData();
      } else {
        _showSnackbar(data['message'] ?? 'เกิดข้อผิดพลาด', false);
      }
    } catch (e) {
      _showSnackbar('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    }
  }

  Future<void> _updateMachine({
    required String machineId,
    required String name,
    required String type,
    required int capacity,
    required double price,
    required int workMinutes,
  }) async {
    try {
      if (url.isEmpty) {
        _showSnackbar('ไม่พบค่า API Endpoint', false);
        return;
      }

      final req = UpdateMachineRequest(
        name: name.trim(),
        type: type,
        capacity: capacity,
        price: price,
        workMinutes: workMinutes,
      );

      final res = await http.put(
        Uri.parse('$url/store/machine/update/$machineId'),
        headers: {'Content-Type': 'application/json'},
        body: updateMachineRequestToJson(req),
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['ok'] == true) {
        if (Get.isDialogOpen ?? false) {
          Get.back();
        }
        _showSnackbar(data['message'] ?? 'แก้ไขเครื่องสำเร็จ', true);
        await _loadData();
      } else {
        _showSnackbar(data['message'] ?? 'เกิดข้อผิดพลาด', false);
      }
    } catch (e) {
      _showSnackbar('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    }
  }

  Future<void> _deleteMachine(String machineId) async {
    try {
      final res = await http.delete(
        Uri.parse('$url/store/machine/delete/$machineId'),
        headers: {'Content-Type': 'application/json'},
      );

      final data = json.decode(res.body);

      if (res.statusCode == 200 && data['ok'] == true) {
        Get.back();
        _showSnackbar(data['message'] ?? 'ลบเครื่องสำเร็จ', true);
        await _loadData();
      } else {
        _showSnackbar(data['message'] ?? 'เกิดข้อผิดพลาด', false);
      }
    } catch (e) {
      _showSnackbar('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', false);
    }
  }

  void _showSnackbar(String message, bool ok) {
    Get.snackbar(
      ok ? 'สำเร็จ' : 'ข้อผิดพลาด',
      message,
      backgroundColor: ok ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
      colorText: Colors.white,
      icon: Icon(ok ? Icons.check_circle : Icons.error, color: Colors.white),
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      duration: const Duration(seconds: 3),
    );
  }

  void _showAddDialog() {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController();
    final capacity = TextEditingController();
    final price = TextEditingController();
    final workMinutes = TextEditingController();

    String selectedType = 'washer';
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0476D9)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'เพิ่มเครื่องใหม่',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Get.back(),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            _dropdown(
                              selectedType,
                              (v) => setState(() => selectedType = v),
                            ),
                            const SizedBox(height: 14),
                            _field('ชื่อเครื่อง', name, 'เช่น เครื่องซัก A1'),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    'ราคา (บาท)',
                                    price,
                                    '40',
                                    isNumber: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    'ความจุ (กก.)',
                                    capacity,
                                    '10',
                                    isNumber: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _field(
                              'ระยะเวลา (นาที)',
                              workMinutes,
                              '30',
                              isNumber: true,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed:
                                        isLoading ? null : () => Get.back(),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFF1F5F9),
                                      foregroundColor:
                                          const Color(0xFF64748B),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            setState(
                                              () => isLoading = true,
                                            );

                                            await _submitMachine(
                                              name: name.text.trim(),
                                              type: selectedType,
                                              capacity: int.parse(
                                                capacity.text,
                                              ),
                                              price: double.parse(
                                                price.text,
                                              ),
                                              workMinutes: int.parse(
                                                workMinutes.text,
                                              ),
                                            );

                                            setState(
                                              () => isLoading = false,
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'ยืนยัน',
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showEditDialog(Machine machine) {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: machine.name);
    final capacity = TextEditingController(text: machine.capacity.toString());
    final price =
        TextEditingController(text: machine.price.toStringAsFixed(0));
    final workMinutes = TextEditingController(
      text: machine.workMinutes.toString(),
    );

    String selectedType = machine.type;
    bool isLoading = false;

    Get.dialog(
      StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF007AFF), Color(0xFF0476D9)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'แก้ไขข้อมูลเครื่อง',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Get.back(),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: formKey,
                        child: Column(
                          children: [
                            _dropdown(
                              selectedType,
                              (v) => setState(() => selectedType = v),
                            ),
                            const SizedBox(height: 14),
                            _field('ชื่อเครื่อง', name, 'เช่น เครื่องซัก A1'),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: _field(
                                    'ราคา (บาท)',
                                    price,
                                    '40',
                                    isNumber: true,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _field(
                                    'ความจุ (กก.)',
                                    capacity,
                                    '10',
                                    isNumber: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _field(
                              'ระยะเวลา (นาที)',
                              workMinutes,
                              '30',
                              isNumber: true,
                            ),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed:
                                        isLoading ? null : () => Get.back(),
                                    style: TextButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFF1F5F9),
                                      foregroundColor:
                                          const Color(0xFF64748B),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: isLoading
                                        ? null
                                        : () async {
                                            if (!formKey.currentState!
                                                .validate()) {
                                              return;
                                            }

                                            setState(
                                              () => isLoading = true,
                                            );

                                            await _updateMachine(
                                              machineId: machine.machineId,
                                              name: name.text.trim(),
                                              type: selectedType,
                                              capacity: int.parse(
                                                capacity.text,
                                              ),
                                              price: double.parse(
                                                price.text,
                                              ),
                                              workMinutes: int.parse(
                                                workMinutes.text,
                                              ),
                                            );

                                            setState(
                                              () => isLoading = false,
                                            );
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF007AFF),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.5,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                        : const Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.save_rounded,
                                                size: 18,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'บันทึก',
                                                style: TextStyle(
                                                  fontWeight:
                                                      FontWeight.bold,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(Machine machine) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF3B30).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: Color(0xFFFF3B30),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ยืนยันการลบ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'คุณต้องการลบ "${machine.name}" ใช่หรือไม่',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF64748B),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ยกเลิก',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _deleteMachine(machine.machineId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ลบ',
                        style: TextStyle(fontWeight: FontWeight.bold),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildAddButton(),
                  const SizedBox(height: 20),
                  _buildSection(
                    'เครื่องซัก',
                    Icons.local_laundry_service,
                    washers,
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                      'เครื่องอบ', Icons.local_laundry_service, dryers),
                ],
              ),
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
          ),
        ),
      ),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'จัดการเครื่องซัก อบ',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildAddButton() {
    return InkWell(
      onTap: _showAddDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF34C759), Color(0xFF28A745)],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.add, color: Color(0xFF28A745), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'เพิ่มเครื่องใหม่',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Machine> machines) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: const Color(0xFF007AFF), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF007AFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${machines.length} เครื่อง',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (machines.isEmpty)
          _buildEmptyState(title)
        else
          ...machines.map((m) => _buildMachineCard(m)),
      ],
    );
  }

  Widget _buildEmptyState(String title) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'ยังไม่มี$title',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(MachineStatus status) {
    final config = switch (status) {
      MachineStatus.available => (
          label: 'ว่าง',
          color: const Color(0xFF34C759),
        ),
      MachineStatus.busy => (
          label: 'ไม่ว่าง',
          color: const Color(0xFFFF9500),
        ),
      MachineStatus.maintenance => (
          label: 'ปิดปรับปรุง',
          color: const Color(0xFFFF3B30),
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: config.color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            config.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMachineCard(Machine machine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  machine.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(machine.status),
            ],
          ),
          const SizedBox(height: 8),
          _infoRow('ราคา', '${machine.price.toStringAsFixed(0)} บาท'),
          const SizedBox(height: 4),
          _infoRow('ความจุ', '${machine.capacity} กก.'),
          const SizedBox(height: 4),
          _infoRow('ระยะเวลา', '${machine.workMinutes} นาที'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showEditDialog(machine),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('แก้ไข'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF007AFF),
                    side:
                        const BorderSide(color: Color(0xFF007AFF), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _dropdown(String value, Function(String) onChanged) {
    final typeMap = {'เครื่องซัก': 'washer', 'เครื่องอบ': 'dryer'};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ประเภทเครื่อง',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: Colors.white,
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF007AFF),
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            items: typeMap.entries
                .map(
                  (e) => DropdownMenuItem<String>(
                    value: e.value,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_laundry_service_rounded,
                          size: 18,
                          color: Color(0xFF007AFF),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          e.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (val) {
              if (val != null) onChanged(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String hint, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'กรุณากรอก$label';
              if (isNumber && double.tryParse(v.trim()) == null) {
                return 'กรุณากรอกตัวเลข';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }
}