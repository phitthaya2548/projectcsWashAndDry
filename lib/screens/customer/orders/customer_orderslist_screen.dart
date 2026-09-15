import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_orderlist_customer.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_completed_screen.dart';
import 'package:wash_and_dry/screens/customer/customer_map_screen.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_order_detail_screen.dart';
import 'package:wash_and_dry/screens/customer/customer_review_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF29B6F6);
  static const _dark = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF5F7FA);

  late final TabController _tab = TabController(length: 3, vsync: this);
  String? _customerId;
  String _baseUrl = '';
  bool _loading = true;
  String? _error;
  List<OrderItem> _allOrders = [];
  final Map<String, StreamSubscription<DocumentSnapshot>> _subscriptions = {};
  final Map<String, String> _statuses = {};
  final Map<String, Timestamp> _liveOrderDatetime = {};
  final Map<String, bool> _reviewed = {};

  static const _activeStatuses = {
    'pending_confirmation',
    'waiting_payment',
    'payment_completed',
    'waiting_pickup',
    'pickup_in_progress',
    'pickup_completed',
    'arrived_at_shop',
    'waiting_wash',
    'washing',
    'waiting_dry',
    'drying',
    'waiting_delivery',
    'delivery_heading_to_shop',
    'delivery_pickup_completed',
    'store_pickup_in_progress',
    'delivery_in_progress',
  };

  static const _doneStatuses = {'completed'};
  static const _cancelStatuses = {'cancelled'};

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _tab.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _baseUrl = config['apiEndpoint']?.toString() ?? '';
      _customerId = await Session().getCustomerId();

      if (!mounted) return;

      if (_customerId == null || _baseUrl.isEmpty) {
        setState(() {
          _error = 'ไม่พบข้อมูลผู้ใช้';
          _loading = false;
        });
        return;
      }

      await _fetchOrders();
    } catch (e) {
      log('_init error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'เกิดข้อผิดพลาด';
        _loading = false;
      });
    }
  }

  Future<void> _fetchOrders() async {
    try {
      final uri = Uri.parse('$_baseUrl/order/customer/list/$_customerId');
      final res = await http.get(uri);

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _error = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})';
          _loading = false;
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (body['ok'] != true) {
        setState(() {
          _error = body['message'] as String? ?? 'เกิดข้อผิดพลาด';
          _loading = false;
        });
        return;
      }

      final list = (body['data'] as List<dynamic>? ?? [])
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final order in list) {
        _statuses.putIfAbsent(order.orderId, () => order.initialStatus);
        _reviewed[order.orderId] = order.isReviewed;
        _listenToOrder(order.orderId);
      }

      if (!mounted) return;

      setState(() {
        _allOrders = list;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      log('_fetchOrders error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'เกิดข้อผิดพลาด';
        _loading = false;
      });
    }
  }

  void _listenToOrder(String orderId) {
    if (_subscriptions.containsKey(orderId)) return;

    _subscriptions[orderId] = FirebaseFirestore.instance
        .collection('orders')
        .doc(orderId)
        .snapshots()
        .listen((snap) {
      if (!mounted || !snap.exists) return;

      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final newStatus = data['status'] as String?;
      final newDatetime = data['order_datetime'];
      final statusChanged = newStatus != null && newStatus != _statuses[orderId];
      final hasTimestamp = newDatetime is Timestamp;
      final datetimeChanged = hasTimestamp && newDatetime != _liveOrderDatetime[orderId];

      if (!statusChanged && !datetimeChanged) return;

      setState(() {
        if (statusChanged) _statuses[orderId] = newStatus;
        if (hasTimestamp) _liveOrderDatetime[orderId] = newDatetime;
      });
    }, onError: (e) {
      log('listen order $orderId error: $e');
    });
  }

  String _statusLabel(String s) => {
        'pending_confirmation': 'รอยืนยันคำสั่งซื้อ',
        'waiting_payment': 'รอชำระเงิน',
        'payment_completed': 'ชำระเงินแล้ว',
        'waiting_pickup': 'รอรับผ้า',
        'pickup_in_progress': 'กำลังไปรับผ้า',
        'pickup_completed': 'รับผ้าเรียบร้อยกำลังไปที่ร้าน',
        'arrived_at_shop': 'มาถึงร้านแล้ว',
        'waiting_wash': 'รอซัก',
        'washing': 'กำลังซักผ้า',
        'waiting_dry': 'รออบผ้า',
        'drying': 'กำลังอบผ้า',
        'waiting_delivery': 'รอส่งผ้า',
        'delivery_heading_to_shop': 'กำลังไปรับผ้าที่ร้าน',
        'delivery_pickup_completed': 'รับผ้าที่ร้านแล้ว',
        'store_pickup_in_progress': 'กำลังรับผ้าที่ร้าน',
        'delivery_in_progress': 'กำลังจัดส่ง',
        'completed': 'เสร็จสิ้น',
        'cancelled': 'ยกเลิก',
      }[s] ??
      s;

  Color _statusColor(String s) {
    if (_activeStatuses.contains(s)) return const Color(0xFF0EA5E9);
    if (s == 'completed') return const Color(0xFF22C55E);
    return const Color(0xFFEF4444);
  }

  String _serviceLabel(String s) => {
        'wash': 'ซักอย่างเดียว',
        'dry': 'อบอย่างเดียว',
        'wash_dry': 'ซัก + อบ',
      }[s] ??
      s;

  static const _thaiMonths = [
    '',
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  String _formatDateTime(DateTime dt) {
    return '${dt.day} ${_thaiMonths[dt.month]} ${dt.year + 543} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(Map<String, dynamic>? raw) {
    if (raw == null) return '-';
    final seconds = raw['_seconds'];
    if (seconds == null) return '-';
    final dt = DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000);
    return _formatDateTime(dt);
  }

  String _formatTimestamp(Timestamp ts) => _formatDateTime(ts.toDate());

  String _resolveOrderDatetime(OrderItem order) {
    final live = _liveOrderDatetime[order.orderId];
    if (live != null) return _formatTimestamp(live);
    return _formatDate(order.orderDatetime);
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
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'ประวัติการใช้งาน',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        bottom: TabBar(
          controller: _tab,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: const [
            Tab(text: 'กำลังดำเนินการ'),
            Tab(text: 'เสร็จสิ้น'),
            Tab(text: 'ยกเลิก/ล้มเหลว'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red.shade400)))
              : TabBarView(
                  controller: _tab,
                  children: [
                    _buildTab(_activeStatuses),
                    _buildTab(_doneStatuses),
                    _buildTab(_cancelStatuses),
                  ],
                ),
    );
  }

  Widget _buildTab(Set<String> bucket) {
    final filtered = _allOrders
        .where((o) => bucket.contains(_statuses[o.orderId] ?? ''))
        .toList();

    if (filtered.isEmpty) return _emptyView();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final order = filtered[i];
        return _card(order, _statuses[order.orderId] ?? '');
      },
    );
  }

  Widget _emptyView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16),
              ],
            ),
            child: const Icon(Icons.inbox_outlined, size: 36, color: Colors.black26),
          ),
          const SizedBox(height: 16),
          const Text(
            'ไม่มีรายการ',
            style: TextStyle(color: Colors.black38, fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _card(OrderItem order, String status) {
    final shortId =
        '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}';
    final statusColor = _statusColor(status);
    final isActive = _activeStatuses.contains(status);
    final isCancelled = _cancelStatuses.contains(status);
    final isReviewed = _reviewed[order.orderId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  shortId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _dark,
                  ),
                ),
                const Spacer(),
                _StatusBadge(
                  label: _statusLabel(status),
                  color: statusColor,
                  isActive: isActive,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _infoRow(Icons.access_time_rounded, _resolveOrderDatetime(order), _dark),
                _infoRow(Icons.person_rounded, order.customerFullname, _dark),
                _infoRow(Icons.location_on_rounded, order.addressFull, Colors.black54),
                _infoRow(Icons.phone_rounded, order.customerPhone, Colors.black54),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.local_laundry_service_rounded,
                    size: 18,
                    color: _primary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'บริการ: ${_serviceLabel(order.serviceType)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: status == 'completed'
                ? Row(
                    children: [
                      if (!isReviewed) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFBBF24),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () async {
                              final result = await Get.to(
                                () => CustomerReviewScreen(orderId: order.orderId),
                              );

                              if (result == true && mounted) {
                                setState(() {
                                  _reviewed[order.orderId] = true;
                                });
                                await _fetchOrders();
                              }
                            },
                            icon: const Icon(Icons.star_rounded, size: 18),
                            label: const Text(
                              'ให้คะแนน',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            await Get.to(
                              () => CustomerCompletedScreen(orderId: order.orderId),
                            );
                            if (!mounted) return;
                            await _fetchOrders();
                          },
                          child: const Text(
                            'ใบเสร็จ',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  )
                : isCancelled
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _dark,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Get.to(
                            () => CustomerOrderDetailScreen(orderId: order.orderId),
                          ),
                          child: const Text(
                            'รายละเอียด',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Get.to(
                                () => CustomerMapScreen(orderId: order.orderId),
                              ),
                              child: const Text(
                                'ติดตาม',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _dark,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => Get.to(
                                () => CustomerOrderDetailScreen(orderId: order.orderId),
                                
                              ),
                              
                              child: const Text(
                                'รายละเอียด',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _infoRow(IconData icon, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color.fromARGB(255, 188, 188, 189)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.isActive,
  });

  final String label;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) _PulsingDot(color: color),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color});

  final Color color;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> {
  bool _bright = true;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_bright),
      tween: Tween(
        begin: _bright ? 0.3 : 1.0,
        end: _bright ? 1.0 : 0.3,
      ),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      onEnd: () {
        if (mounted) setState(() => _bright = !_bright);
      },
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}