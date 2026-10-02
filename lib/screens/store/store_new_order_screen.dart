import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/screens/store/store_befororder_detail_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';

const Color kInk = Color(0xFF1A1A1A);

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

class StoreNewOrdersScreen extends StatefulWidget {
  const StoreNewOrdersScreen({super.key});

  @override
  State<StoreNewOrdersScreen> createState() => _StoreNewOrdersScreenState();
}

class _StoreNewOrdersScreenState extends State<StoreNewOrdersScreen> {
  String url = '';
  String? storeId;
  bool isLoading = true;
  String? errorMessage;

  List<_StoreOrderItem> _cachedOrders = [];
  bool _enriching = false;
  List<String> _lastDocIds = [];
  final Map<String, DocumentSnapshot> _customerCache = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';

      final session = Session();
      storeId = await session.getStoreId();

      if (url.isEmpty) throw Exception('ไม่พบ API URL');
      if (storeId == null || storeId!.isEmpty) {
        throw Exception('ไม่พบ Store ID - กรุณาเข้าสู่ระบบใหม่');
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      log('StoreNewOrdersScreen error: $e');
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
    final sameDocs = _listEquals(_lastDocIds, newIds) && _cachedOrders.isNotEmpty;
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
    final refsToFetch = <DocumentReference>[];
    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final ref = d['customer_id'];
      if (ref is DocumentReference && !_customerCache.containsKey(ref.path)) {
        refsToFetch.add(ref);
      }
    }

    if (refsToFetch.isNotEmpty) {
      final snaps = await Future.wait(refsToFetch.map((r) => r.get()));
      for (final s in snaps) {
        _customerCache[s.reference.path] = s;
      }
    }

    return docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;
      String name = 'ไม่ระบุชื่อ';

      try {
        final ref = d['customer_id'];
        if (ref is DocumentReference) {
          final cs = _customerCache[ref.path];
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
          .put(
            Uri.parse('$url/order/store/accept/$orderId'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'store_id': storeId}),
          )
          .timeout(const Duration(seconds: 10));

      final body = json.decode(res.body);
      final ok = body['ok'] == true;
      _showSnack(
        body['message']?.toString() ?? (ok ? 'รับออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด'),
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

    final confirmed = await _showCancelConfirmDialog();
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
        body['message']?.toString() ?? (ok ? 'ยกเลิกออเดอร์สำเร็จ' : 'เกิดข้อผิดพลาด'),
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

  /// Dialog ยืนยันยกเลิกออเดอร์ สไตล์ GetX โค้งมน มีไอคอนเตือน
  Future<bool?> _showCancelConfirmDialog() {
    return Get.dialog<bool>(
      Dialog(
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
                  color: kInk,
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
                        foregroundColor: kInk,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'ไม่ใช่',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
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
      transitionCurve: Curves.easeOutBack,
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;

    final isSuccess = color == const Color(0xFF34C759);
    final isError = color == Colors.red;
    final icon = isSuccess
        ? Icons.check_circle_rounded
        : isError
            ? Icons.error_rounded
            : Icons.info_rounded;

    Get.snackbar(
      '',
      '',
      titleText: const SizedBox.shrink(),
      messageText: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      backgroundColor: color,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      borderRadius: 14,
      barBlur: 8,
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutBack,
      reverseAnimationCurve: Curves.easeIn,
      duration: const Duration(seconds: 3),
      boxShadows: [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'ออเดอร์ใหม่',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ออเดอร์รอยืนยัน',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            '${_cachedOrders.length} รายการ',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildOrderList()),
                  ],
                ),
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
            Text(errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() => isLoading = true);
                _loadData();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    final storeRef = FirebaseFirestore.instance.collection('stores').doc(storeId!);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('store_id', isEqualTo: storeRef)
          .where('status', isEqualTo: 'pending_confirmation')
          .orderBy('order_datetime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _cachedOrders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) return _buildEmpty();

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _maybeEnrichOrders(docs);
        });

        if (_cachedOrders.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () async {
            _lastDocIds = [];
            await _maybeEnrichOrders(docs);
          },
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: _cachedOrders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _cachedOrders[index];
              return _NewOrderCard(
                item: item,
                onAccept: () => _acceptOrder(item.orderId),
                onDetail: () => _openDetail(item.orderId),
                onCancel: () => _cancelOrder(item.orderId),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text('ยังไม่มีออเดอร์ใหม่', style: TextStyle(color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _NewOrderCard extends StatelessWidget {
  final _StoreOrderItem item;
  final VoidCallback onAccept;
  final VoidCallback onDetail;
  final VoidCallback onCancel;

  const _NewOrderCard({
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 3)),
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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.access_time, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 3),
                  Text(_timeText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade500),
                      onSelected: (value) {
                        if (value == 'cancel') onCancel();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'cancel',
                          child: Text('ยกเลิกออเดอร์', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('#$_orderCode', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('รับออเดอร์', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('รายละเอียด', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}