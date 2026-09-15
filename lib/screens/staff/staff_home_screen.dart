import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/staff/req_accept_staff.dart';
import 'package:wash_and_dry/screens/staff/staff_order_detail_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstaff.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class _OrderItem {
  final String orderId;
  final Map<String, dynamic> data;
  final String customerName;
  final String customerPhone;
  final String addressText;

  const _OrderItem({
    required this.orderId,
    required this.data,
    required this.customerName,
    required this.customerPhone,
    required this.addressText,
  });
}

class StaffHomeScreen extends StatefulWidget {
  const StaffHomeScreen({super.key});

  @override
  State<StaffHomeScreen> createState() => _StaffHomeScreenState();
}

class _StaffHomeScreenState extends State<StaffHomeScreen> {
  String _url = '';
  String _staffName = '';
  String? _profileImage;
  String? _staffId;
  String? _shopId;
  bool _ready = false;


  String? _initialStatus;

  List<_OrderItem> _cachedOrders = [];
  bool _enriching = false;
  List<String>? _lastDocIds;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      if (!mounted) return;
      setState(() => _url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {}

    final session = Session();
    final name = await session.getFullname();
    final image = await session.getProfileImage();
    final id = await session.getStaffId();
    final status = await session.getStatus();
    String? shopId = await session.getStoreId();

    log('GET profile_image: "$image"');
    if ((shopId == null || shopId.trim().isEmpty) && id != null && id.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('laundry_staff')
            .doc(id)
            .get();
        final ref = doc.data()?['store_id'];
        if (ref is DocumentReference) shopId = ref.id;
      } catch (e) {
        log('loadSession error: $e');
      }
    }
    log("$image");

    if (!mounted) return;
    setState(() {
      _staffName = name ?? '';
      _profileImage = image;
      _staffId = id;
      _shopId = shopId;
      _initialStatus = status;
      _ready = true;
    });
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _maybeEnrichOrders(List<QueryDocumentSnapshot> docs) async {
    final newIds = docs.map((d) => d.id).toList();
    final sameDocs = _lastDocIds != null &&
        _listEquals(_lastDocIds!, newIds) &&
        _cachedOrders.isNotEmpty;

    if (sameDocs || _enriching) return;

    _enriching = true;
    _lastDocIds = newIds;

    try {
      final items = await _enrichOrders(docs);
      if (!mounted) return;
      setState(() => _cachedOrders = items);
    } finally {
      _enriching = false;
    }
  }

  Future<List<_OrderItem>> _enrichOrders(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final futures = docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      String name = 'ไม่ระบุชื่อ', phone = '', addressText = 'ไม่ระบุที่อยู่';

      try {
        final res = await Future.wait([
          _fetchCustomer(data['customer_id']),
          _fetchAddress(data['address_id']),
        ]);
        final c = res[0] as ({String name, String phone});
        final a = res[1] as ({String text});
        name = c.name;
        phone = c.phone;
        addressText = a.text;
      } catch (e) {
        log('enrichOrders error for ${doc.id}: $e');
      }

      return _OrderItem(
        orderId: doc.id,
        data: data,
        customerName: name,
        customerPhone: phone,
        addressText: addressText,
      );
    });

    return List<_OrderItem>.from(await Future.wait(futures));
  }

  Future<({String name, String phone})> _fetchCustomer(dynamic ref) async {
    if (ref is DocumentReference) {
      final snap = await ref.get();
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>?;
        return (
          name: d?['fullname']?.toString() ?? 'ไม่ระบุชื่อ',
          phone: d?['phone']?.toString() ?? '',
        );
      }
    }
    return (name: 'ไม่ระบุชื่อ', phone: '');
  }

  Future<({String text})> _fetchAddress(dynamic ref) async {
    if (ref is DocumentReference) {
      final snap = await ref.get();
      if (snap.exists) {
        final d = snap.data() as Map<String, dynamic>?;
        return (text: d?['address_text']?.toString() ?? 'ไม่ระบุที่อยู่');
      }
    }
    return (text: 'ไม่ระบุที่อยู่');
  }

  // (ไม่ใช่ field ที่คำนวณครั้งเดียวตอนสร้าง object เหมือนโค้ดเดิม)
  String _statusText(String? status) => switch (status) {
        'ONLINE' => 'ใช้งาน',
        'TEMP_CLOSED' => 'ปิดชั่วคราว',
        _ => status ?? 'ไม่ทราบสถานะ',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBarStaff(
        staffName: _staffName,
        staffId: _staffId ?? '',
        profileImage: _profileImage,
      ),
      body: !_ready || _staffId == null || (_shopId?.isEmpty ?? true)
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('laundry_staff')
                  .doc(_staffId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() as Map<String, dynamic>?;

                final currentStatus =
                    data?['status']?.toString() ?? _initialStatus;

                if (currentStatus != 'ONLINE') {
                  return _buildInactiveState(currentStatus);
                }
                return _buildBody();
              },
            ),
    );
  }

  Widget _buildInactiveState(String? status) {
    final statusText = _statusText(status);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.pause_circle_outline_rounded,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'สถานะของคุณคือ "$statusText"',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'จะไม่มีการแสดงงานใหม่จนกว่าจะเปลี่ยนสถานะเป็น "ใช้งาน"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final storeRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(_shopId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'รอดำเนินการ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('store_id', isEqualTo: storeRef)
                .where('status', whereIn: ['waiting_wash', 'waiting_dry'])
                .where('staff_id', isNull: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedOrders.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isNotEmpty) {
                _maybeEnrichOrders(docs);
              } else if (_cachedOrders.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _cachedOrders = []);
                });
              }

              if (_cachedOrders.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox_outlined,
                          size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text(
                        'ไม่มีงานรอดำเนินการในขณะนี้',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 15),
                      ),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _cachedOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _OrderCard(
                  item: _cachedOrders[index],
                  onStartWash: () => _startWash(_cachedOrders[index].orderId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _startWash(String orderId) async {
    try {
      final uri = Uri.parse('$_url/order/staff/start_wash/$orderId');

      final response = await http.put(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: startWashRequestToJson(StartWashRequest(staffId: _staffId!)),
      );

      final result = startWashResponseFromJson(response.body);

      if (response.statusCode == 200 && result.ok) {
        _showSnack(result.message, const Color(0xFF34C759));
      } else {
        _showSnack(result.message, Colors.orange);
      }
    } on http.ClientException {
      _showSnack('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้', Colors.red);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), Colors.orange);
    }
  }
}

class _OrderCard extends StatelessWidget {
  final _OrderItem item;
  final VoidCallback onStartWash;

  const _OrderCard({
    required this.item,
    required this.onStartWash,
  });

  String _serviceLabel(String s) =>
      const {
        'wash': 'ซักผ้าอย่างเดียว',
        'dry': 'อบผ้าอย่างเดียว',
        'wash_dry': 'ซัก + อบ',
      }[s] ??
      s;

  String get _orderDateTimeText {
    final timestamp = item.data['order_datetime'];

    if (timestamp is! Timestamp) return '';

    final dateTime = timestamp.toDate();

    return '${dateTime.day}/${dateTime.month}/${dateTime.year + 543} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')} น.';
  }

  @override
  Widget build(BuildContext context) {
    final isDry = item.data['status'] == 'waiting_dry';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        16,
                        14,
                        16,
                        10,
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '#${item.orderId.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF5FF),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(
                              isDry ? 'รออบ' : 'รอซัก',
                              style: const TextStyle(
                                color: Color(0xFF0593FF),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),

                          const SizedBox(height: 6),

                          _iconRow(
                            Icons.location_on_outlined,
                            item.addressText,
                          ),

                          if (item.customerPhone.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _iconRow(
                              Icons.phone_outlined,
                              item.customerPhone,
                            ),
                          ],

                          if (_orderDateTimeText.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _iconRow(
                              Icons.access_time,
                              _orderDateTimeText,
                            ),
                          ],

                          const SizedBox(height: 10),

                          _buildChip(
                            'บริการ:',
                            _serviceLabel(
                              item.data['service_type']
                                      ?.toString() ??
                                  '',
                            ),
                            Colors.grey.shade100,
                            Colors.black87,
                            icon:
                                Icons.local_laundry_service,
                          ),

                          if ((item.data['note']
                                      ?.toString() ??
                                  '')
                              .isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'หมายเหตุ: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        Colors.grey.shade600,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.data['note']
                                        .toString(),
                                    style:
                                        const TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        0,
                        14,
                        14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Get.to(
                                  () =>
                                      StaffOrderDetailScreen(
                                    orderId:
                                        item.orderId,
                                  ),
                                );
                              },
                              style:
                                  OutlinedButton.styleFrom(
                                foregroundColor:
                                    const Color(
                                        0xFF0593FF),
                                side: const BorderSide(
                                  color:
                                      Color(0xFF0593FF),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
                                ),
                              ),
                              child: const Text(
                                'รายละเอียด',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: onStartWash,
                             
                              label: Text(
                                'เริ่มคำนวณ',
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                              style:
                                  ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(
                                        0xFF0593FF),
                                foregroundColor:
                                    Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                elevation: 0,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconRow(
    IconData icon,
    String text,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: Colors.grey.shade500,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(
    String label,
    String value,
    Color bg,
    Color textColor, {
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 25,
              color: Colors.blue.shade500,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

  Widget _buildChip(String label, String value, Color bg, Color textColor,
      {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 25, color: Colors.blue.shade500),
            const SizedBox(width: 4),
          ],
          Text(label,
              style:
                  TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(width: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor)),
        ],
      ),
    );
  }
