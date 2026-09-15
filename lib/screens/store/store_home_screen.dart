import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_order_completed_customer.dart';
import 'package:wash_and_dry/models/res/customer/store/res_list_register_employee_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_profile_store.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_manage_employee_screen.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_managemachine_screen.dart';
import 'package:wash_and_dry/screens/store/store_befororder_detail_screen.dart';
import 'package:wash_and_dry/screens/store/store_new_order_screen.dart';
import 'package:wash_and_dry/screens/store/store_review_screen.dart';

import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstore.dart';

const List<String> kOrderStatusOrder = [
  'pending_confirmation',
  'waiting_pickup',
  'pickup_in_progress',
  'pickup_completed',
  'waiting_payment',
  'payment_completed',
  'waiting_wash',
  'washing',
  'waiting_dry',
  'drying',
  'waiting_delivery',
  'delivery_in_progress',
  'completed',
];

class _StoreOrderItem {
  final String orderId;
  final Map<String, dynamic> data;
  final String customerName;
  final DateTime? orderDatetime;

  const _StoreOrderItem({
    required this.orderId,
    required this.data,
    required this.customerName,
    this.orderDatetime,
  });
}

class StoreHomeScreen extends StatefulWidget {
  const StoreHomeScreen({super.key});

  @override
  State<StoreHomeScreen> createState() => _StoreHomeScreenState();
}

class _StoreHomeScreenState extends State<StoreHomeScreen> {
  String url = '';
  StoreData? storeData;
  bool isLoading = true;
  String? errorMessage;
  String? storeId;

  List<_StoreOrderItem> _cachedOrders = [];
  bool _enriching = false;
  List<String> _lastDocIds = [];

  static const int _latestOrderLimit = 3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      log('API URL: $url');

      final session = Session();
      storeId = await session.getStoreId();
      log('Store ID: $storeId');

      if (url.isEmpty) throw Exception('ไม่พบ API URL');
      if (storeId == null || storeId!.isEmpty) {
        throw Exception('ไม่พบ Store ID - กรุณาเข้าสู่ระบบใหม่');
      }

      await _getStoreProfile();
    } catch (e) {
      log('Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getStoreProfile() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final uri = Uri.parse('$url/store/profile/$storeId');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = json.decode(res.body);
      if (body['ok'] != true) {
        throw Exception(body['message'] ?? 'ดึงข้อมูลไม่สำเร็จ');
      }

      final storeJson = body['data'];
      if (storeJson == null) throw Exception('ไม่พบข้อมูลร้านค้า');

      if (mounted) {
        setState(() {
          storeData = StoreData.fromJson(storeJson);
          isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          errorMessage = 'เซิร์ฟเวอร์ช้า';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          isLoading = false;
        });
      }
    }
  }

  Future<void> _maybeEnrichOrders(List<QueryDocumentSnapshot> docs) async {
    final newIds = docs.map((d) => d.id).toList();
    final sameDocs =
        _listEquals(_lastDocIds, newIds) && _cachedOrders.isNotEmpty;
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

  Future<List<_StoreOrderItem>> _enrichOrders(
    List<QueryDocumentSnapshot> docs,
  ) async {
    final customerRefs = <DocumentReference>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final ref = d['customer_id'];
      if (ref is DocumentReference) customerRefs.add(ref);
    }

    final customerSnaps = await _batchGet(customerRefs);

    return docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      String name = 'ไม่ระบุชื่อ';

      try {
        final ref = d['customer_id'];
        if (ref is DocumentReference) {
          final cs = customerSnaps[ref.path];
          if (cs != null && cs.exists) {
            final cd = cs.data() as Map<String, dynamic>?;
            name = cd?['fullname']?.toString() ?? 'ไม่ระบุชื่อ';
          }
        }
      } catch (e) {
        log('enrichOrders error for ${doc.id}: $e');
      }

      DateTime? dt;
      final ts = d['order_datetime'];
      if (ts is Timestamp) dt = ts.toDate();

      return _StoreOrderItem(
        orderId: doc.id,
        data: d,
        customerName: name,
        orderDatetime: dt,
      );
    }).toList();
  }

  Future<Map<String, DocumentSnapshot>> _batchGet(
    List<DocumentReference> refs,
  ) async {
    if (refs.isEmpty) return {};
    final snaps = await Future.wait(refs.map((r) => r.get()));
    return {for (final s in snaps) s.reference.path: s};
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _acceptOrder(String orderId) async {
    if (url.isEmpty || storeId == null) {
      _showSnack('ไม่พบข้อมูลร้านค้า', Colors.red);
      return;
    }
    try {
      final res = await http
          .post(
            Uri.parse('$url/order/store/accept/$orderId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'store_id': storeId}),
          )
          .timeout(const Duration(seconds: 10));

      final body = json.decode(res.body);
      final ok = body['ok'] == true;
      _showSnack(
        body['message']?.toString() ??
            (ok ? 'รับออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด'),
        ok ? const Color(0xFF34C759) : Colors.orange,
      );
    } catch (e) {
      log('acceptOrder error: $e');
      _showSnack('เกิดข้อผิดพลาด กรุณาลองใหม่', Colors.red);
    }
  }

  Future<void> _cancelOrder(String orderId) async {
    if (url.isEmpty || storeId == null) {
      _showSnack('ไม่พบข้อมูลร้านค้า', Colors.red);
      return;
    }

    final confirmed = await Get.dialog<bool>(
      const _CancelOrderDialog(),
      barrierDismissible: true,
    );

    if (confirmed != true) return;

    try {
      final res = await http
          .post(
            Uri.parse('$url/order/store/cancel/$orderId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'store_id': storeId}),
          )
          .timeout(const Duration(seconds: 10));

      final body = json.decode(res.body);
      final ok = body['ok'] == true;
      _showSnack(
        body['message']?.toString() ??
            (ok ? 'ยกเลิกออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด'),
        ok ? const Color(0xFF34C759) : Colors.orange,
      );
    } catch (e) {
      log('cancelOrder error: $e');
      _showSnack('เกิดข้อผิดพลาด กรุณาลองใหม่', Colors.red);
    }
  }

  void _openDetail(String orderId) {
    Get.to(() => StoreOrderDetailScreen(orderId: orderId));
  }

  void _showSnack(String msg, Color color) {
  Get.snackbar(
    '',
    msg,
    backgroundColor: color,
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(8),
    duration: const Duration(seconds: 3),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: storeData == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: StoreAppBar(
                title: storeData?.storeName ?? '',
                profileImage: storeData?.profileImage,
                storeId: storeData?.storeId ?? '',
              ),
            ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูลร้าน...'),
                ],
              ),
            )
          : errorMessage != null
          ? _buildError()
          : _buildDashboard(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard() {
    final storeRef = FirebaseFirestore.instance
        .collection('stores')
        .doc(storeId!);
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    return RefreshIndicator(
      onRefresh: _getStoreProfile,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('store_id', isEqualTo: storeRef)
            .orderBy('order_datetime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedOrders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          final todayDocs = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final ts = d['order_datetime'];
            if (ts is Timestamp) return !ts.toDate().isBefore(startOfDay);
            return false;
          }).toList();

          final pendingTodayDocs = todayDocs.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']
                ?.toString();
            return status != 'completed' && status != 'cancelled';
          }).toList();

          final completedTodayDocs = todayDocs.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']
                ?.toString();
            return status == 'completed';
          }).toList();

          final todayRevenue = todayDocs.fold<int>(0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status']?.toString() ?? '';
            if (status != 'completed')
              return sum;
            final servicePrice = (data['service_price'] as num?)?.toInt() ?? 0;
            final deliveryPrice =
                (data['delivery_price'] as num?)?.toInt() ?? 0;
            final detergentPrice =
                (data['detergent_price'] as num?)?.toInt() ?? 0;
            return sum + servicePrice + deliveryPrice + detergentPrice;
          });

          final pendingDocs = allDocs.where((doc) {
            final status = (doc.data() as Map<String, dynamic>)['status']
                ?.toString();
            return status == 'pending_confirmation';
          }).toList();

          final latestDocs = pendingDocs.take(_latestOrderLimit).toList();
          if (latestDocs.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _maybeEnrichOrders(latestDocs);
            });
          }

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsRow(todayDocs.length, todayRevenue),
                const SizedBox(height: 12),
                _buildStatusRow(
                  pendingTodayDocs.length,
                  completedTodayDocs.length,
                ),
                const SizedBox(height: 16),
                _buildQuickMenu(),
                const SizedBox(height: 16),
                _buildLatestOrdersHeader(),
                const SizedBox(height: 8),
                if (latestDocs.isEmpty)
                  _buildEmptyOrders()
                else if (_cachedOrders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  Column(
                    children: _cachedOrders
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _StoreOrderCard(
                              item: item,
                              onAccept: () => _acceptOrder(item.orderId),
                              onDetail: () => _openDetail(item.orderId),
                              onCancel: () => _cancelOrder(item.orderId),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsRow(int orderCount, int revenue) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.inventory_2_outlined,
            iconBg: const Color(0xFF0593FF),
            label: 'ออเดอร์วันนี้',
            value: '$orderCount',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.attach_money,
            iconBg: const Color(0xFF34C759),
            label: 'รายได้วันนี้',
            value: '$revenue ฿',
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(int pendingCount, int completedCount) {
    return Row(
      children: [
        Expanded(
          child: _StatusMiniCard(
            label: 'รอดำเนินการ',
            value: '$pendingCount',
            bg: const Color(0xFFFFF3E0),
            valueColor: const Color(0xFFFF9800),
            icon: Icons.access_time,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusMiniCard(
            label: 'เสร็จสิ้นแล้ว',
            value: '$completedCount',
            bg: const Color(0xFFE8F9EE),
            valueColor: const Color(0xFF34C759),
            icon: Icons.trending_up,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMenu() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เมนูด่วน',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _QuickMenuItem(
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF0593FF),
                label: 'ออเดอร์ใหม่',
                onTap: () => Get.to(() => const StoreNewOrdersScreen()),
              ),
              _QuickMenuItem(
                icon: Icons.star_outlined,
              color: const Color(0xFFFFC107),
                label: 'รีวิวร้านค้า',
                onTap: () {
                  Get.to(() => const StoreReviewScreen());
                },
              ),
              _QuickMenuItem(
                icon: Icons.groups_outlined,
                color: const Color(0xFF7C6FDB),
                label: 'พนักงาน',
                onTap: () {
                  Get.to(() => const ManageEmployeeScreen());
                },
              ),
              _QuickMenuItem(
                icon: Icons.local_laundry_service_outlined,
                color: const Color(0xFF5B6B8C),
                label: 'เครื่องซัก/อบ',
                onTap: () {
                  Get.to(() => const ManageMachineScreen());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLatestOrdersHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'ออเดอร์รอยืนยัน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        TextButton(
          onPressed: () {
            Get.to(() => const StoreNewOrdersScreen());
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ดูทั้งหมด',
                style: TextStyle(color: Color(0xFF0593FF), fontSize: 13),
              ),
              Icon(Icons.chevron_right, color: Color(0xFF0593FF), size: 18),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyOrders() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            'ยังไม่มีออเดอร์',
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusMiniCard extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color valueColor;
  final IconData icon;

  const _StatusMiniCard({
    required this.label,
    required this.value,
    required this.bg,
    required this.valueColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: valueColor, size: 18),
          ),
        ],
      ),
    );
  }
}

class _QuickMenuItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickMenuItem({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 70,
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _CancelOrderDialog extends StatelessWidget {
  const _CancelOrderDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: Colors.red,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'ยกเลิกออเดอร์',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'คุณแน่ใจหรือไม่ว่าต้องการยกเลิกออเดอร์นี้?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(result: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ไม่ใช่',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'ยืนยันยกเลิก',
                      style: TextStyle(
                        fontSize: 14,
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
    );
  }
}

class _StoreOrderCard extends StatelessWidget {
  final _StoreOrderItem item;
  final VoidCallback onAccept;
  final VoidCallback onDetail;
  final VoidCallback onCancel;

  const _StoreOrderCard({
    required this.item,
    required this.onAccept,
    required this.onDetail,
    required this.onCancel,
  });

  String get _timeText {
    final dt = item.orderDatetime;
    if (dt == null) return '';
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  String get _orderCode {
    final id = item.orderId;
    return (id.length >= 6 ? id.substring(0, 6) : id).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    const statusLabel = 'รอยืนยันคำสั่งซื้อ';
    const statusColor = Colors.orange;
    const statusIcon = Icons.info_outline;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.customerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time,
                    size: 13,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _timeText,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.more_vert,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                      onSelected: (value) {
                        if (value == 'cancel') onCancel();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text(
                            'ยกเลิกออเดอร์',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '#$_orderCode',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(statusIcon, size: 14, color: statusColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  statusLabel,
                  style: TextStyle(fontSize: 12, color: statusColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0593FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'รับออเดอร์',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDetail,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0593FF),
                    side: const BorderSide(color: Color(0xFF0593FF)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'รายละเอียด',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
