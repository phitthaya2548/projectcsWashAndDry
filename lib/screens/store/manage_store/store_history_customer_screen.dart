import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_getx_widget.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_orderlist_customer.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_order_detail_screen.dart';

enum _HistoryTab { completed, cancelled }

class CustomerServiceHistoryScreen extends StatefulWidget {
  const CustomerServiceHistoryScreen({super.key, required this.customerId});

  final String customerId;

  @override
  State<CustomerServiceHistoryScreen> createState() =>
      _CustomerServiceHistoryScreenState();
}

class _CustomerServiceHistoryScreenState
    extends State<CustomerServiceHistoryScreen> {
  static const _primary = Color(0xFF29B6F6);
  static const _dark = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF5F7FA);

  String _baseUrl = '';
  bool _loading = true;
  String? _error;

  List<OrderItem> _allOrders = [];
  final Map<String, String> _statuses = {};

  _HistoryTab _selectedTab = _HistoryTab.completed;

  static const _doneStatuses = {'completed'};
  static const _cancelStatuses = {'cancelled'};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _baseUrl = config['apiEndpoint']?.toString() ?? '';

      if (!mounted) return;

      if (widget.customerId.isEmpty || _baseUrl.isEmpty) {
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
      final uri = Uri.parse('$_baseUrl/order/customer/list/${widget.customerId}');
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
      }

      final history = list
          .where(
            (o) =>
                _doneStatuses.contains(_statuses[o.orderId]) ||
                _cancelStatuses.contains(_statuses[o.orderId]),
          )
          .toList();

      setState(() {
        _allOrders = history;
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

  List<OrderItem> get _completedOrders => _allOrders
      .where((o) => _doneStatuses.contains(_statuses[o.orderId]))
      .toList();

  List<OrderItem> get _cancelledOrders => _allOrders
      .where((o) => _cancelStatuses.contains(_statuses[o.orderId]))
      .toList();

  List<OrderItem> get _visibleOrders =>
      _selectedTab == _HistoryTab.completed
          ? _completedOrders
          : _cancelledOrders;

  String _statusLabel(String s) =>
      {
        'completed': 'เสร็จสิ้น',
        'cancelled': 'ยกเลิก',
      }[s] ??
      s;

  Color _statusColor(String s) {
    if (s == 'completed') return const Color(0xFF22C55E);
    return const Color(0xFFEF4444);
  }

  String _serviceLabel(String s) =>
      {
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
          'ประวัติบริการทั้งหมด',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Get.back(result: true),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _error != null
          ? Center(
              child: Text(
                _error!,
                style: TextStyle(color: Colors.red.shade400),
              ),
            )
          : Column(
              children: [
                _tabBar(),
                Expanded(
                  child: _visibleOrders.isEmpty
                      ? _emptyView()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: _visibleOrders.length,
                          itemBuilder: (_, i) {
                            final order = _visibleOrders[i];
                            return _card(order, _statuses[order.orderId] ?? '');
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _tabBar() => Container(
    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: _tabButton(
            label: 'สำเร็จ',
            count: _completedOrders.length,
            isSelected: _selectedTab == _HistoryTab.completed,
            selectedColor: const Color(0xFF22C55E),
            onTap: () => setState(() => _selectedTab = _HistoryTab.completed),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: _tabButton(
            label: 'ยกเลิก',
            count: _cancelledOrders.length,
            isSelected: _selectedTab == _HistoryTab.cancelled,
            selectedColor: const Color(0xFFEF4444),
            onTap: () => setState(() => _selectedTab = _HistoryTab.cancelled),
          ),
        ),
      ],
    ),
  );

  Widget _tabButton({
    required String label,
    required int count,
    required bool isSelected,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected ? selectedColor : Colors.black45,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? selectedColor : Colors.black12,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyView() => Center(
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
          child: const Icon(
            Icons.inbox_outlined,
            size: 36,
            color: Colors.black26,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'ไม่มีรายการ',
          style: TextStyle(
            color: Colors.black38,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _card(OrderItem order, String status) {
    final shortId =
        '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}';
    final statusColor = _statusColor(status);

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
                _StatusBadge(label: _statusLabel(status), color: statusColor),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _infoRow(
                  Icons.access_time_rounded,
                  _formatDate(order.orderDatetime),
                  _dark,
                ),
                _infoRow(
                  Icons.person_rounded,
                  order.customerFullname,
                  _dark,
                ),
                _infoRow(
                  Icons.location_on_rounded,
                  order.addressFull,
                  Colors.black54,
                ),
                _infoRow(
                  Icons.phone_rounded,
                  order.customerPhone,
                  Colors.black54,
                ),
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
            child: SizedBox(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color textColor) => Padding(
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}