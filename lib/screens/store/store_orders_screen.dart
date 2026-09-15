import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_orderItem_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_profile_store.dart';

import 'package:wash_and_dry/screens/store/store_completed_screen.dart';
import 'package:wash_and_dry/screens/store/store_afterorder_detail_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstore.dart';

class StoreOrdersScreen extends StatefulWidget {
  const StoreOrdersScreen({super.key});

  @override
  State<StoreOrdersScreen> createState() => _StoreOrdersScreenState();
}

class _StoreOrdersScreenState extends State<StoreOrdersScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF29B6F6);
  static const _dark = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF5F5F5);

  static const _divider = Divider(
    height: 1,
    thickness: 1,
    color: Color(0xFFF1F5F9),
  );
  static final _btnRadius = BorderRadius.circular(10);
  static const _btnPadding = EdgeInsets.symmetric(vertical: 12);
  static const _btnTextStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 14,
  );

  late final TabController _tab = TabController(length: 3, vsync: this);

  String url = '';
  StoreData? storeData;
  bool isLoading = true;
  String? errorMessage;
  String? storeId;

  bool _ordersLoading = true;
  String? _ordersError;
  List<StoreOrderItem> _activeOrders = [];

  bool _historyLoading = true;
  String? _historyError;
  List<StoreOrderItem> _historyOrders = [];

  final Map<String, StreamSubscription<DocumentSnapshot>> _subscriptions = {};
  final Map<String, String> _statuses = {};
  final Map<String, Timestamp> _liveDatetimes = {};

  DateTime? _historySelectedDate;

  static const _activeStatuses = {
    'pending_confirmation',
    'waiting_payment',
    'waiting_pickup',
    'pickup_in_progress',
    'pickup_completed',
    'waiting_wash',
    'washing',
    'waiting_dry',
    'drying',
    'waiting_delivery',
    'store_pickup_in_progress',
    'delivery_in_progress',
  };
  static const _doneStatuses = {'completed'};
  static const _cancelStatuses = {'cancelled'};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final sub in _subscriptions.values) {
      sub.cancel();
    }
    _tab.dispose();
    super.dispose();
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
      await Future.wait([_fetchOrders(), _fetchHistory()]);
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

      if (res.statusCode != 200) throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');

      final body = json.decode(res.body);
      if (body['ok'] != true) throw Exception(body['message'] ?? 'ดึงข้อมูลไม่สำเร็จ');

      final storeJson = body['data'];
      if (storeJson == null) throw Exception('ไม่พบข้อมูลร้านค้า');

      if (mounted) {
        setState(() {
          storeData = StoreData.fromJson(storeJson);
          isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) setState(() { errorMessage = 'เซิร์ฟเวอร์ช้า'; isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { errorMessage = e.toString().replaceAll('Exception: ', ''); isLoading = false; });
    }
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() {
      _ordersLoading = true;
      _ordersError = null;
    });
    try {
      final uri = Uri.parse('$url/order/store/process/list/$storeId');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _ordersError = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})';
          _ordersLoading = false;
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) {
        setState(() {
          _ordersError = body['message'] as String? ?? 'เกิดข้อผิดพลาด';
          _ordersLoading = false;
        });
        return;
      }

      final list = (body['data'] as List<dynamic>? ?? [])
          .map((e) => StoreOrderItem.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final order in list) {
        _statuses.putIfAbsent(order.orderId, () => order.initialStatus);
        _listenToOrder(order.orderId);
      }

      setState(() {
        _activeOrders = list;
        _ordersLoading = false;
      });
    } catch (e) {
      log('_fetchOrders error: $e');
      if (!mounted) return;
      setState(() {
        _ordersError = 'เกิดข้อผิดพลาด';
        _ordersLoading = false;
      });
    }
  }

  Future<void> _fetchHistory() async {
    if (!mounted) return;
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final queryParameters = <String, String>{};
      final selectedDate = _historySelectedDate;

      if (selectedDate != null) {
        queryParameters['day'] = selectedDate.day.toString();
        queryParameters['month'] = selectedDate.month.toString();
        queryParameters['year'] = selectedDate.year.toString();
      }

      final uri = Uri.parse('$url/order/store/history/$storeId').replace(
        queryParameters: queryParameters.isEmpty ? null : queryParameters,
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() {
          _historyError = 'โหลดข้อมูลไม่สำเร็จ (${res.statusCode})';
          _historyLoading = false;
        });
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) {
        setState(() {
          _historyError = body['message'] as String? ?? 'เกิดข้อผิดพลาด';
          _historyLoading = false;
        });
        return;
      }

      final list = (body['data'] as List<dynamic>? ?? [])
          .map((e) => StoreOrderItem.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final order in list) {
        _statuses[order.orderId] = order.initialStatus;
        _listenToOrder(order.orderId);
      }

      setState(() {
        _historyOrders = list;
        _historyLoading = false;
      });
    } catch (e) {
      log('_fetchHistory error: $e');
      if (!mounted) return;
      setState(() {
        _historyError = 'เกิดข้อผิดพลาด';
        _historyLoading = false;
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
          if (!mounted) return;
          if (!snap.exists) return;

          final data = snap.data() as Map<String, dynamic>?;
          if (data == null) return;

          final newStatus = data['status'] as String?;
          final newDatetime = data['order_datetime'];

          final statusChanged = newStatus != null && newStatus != _statuses[orderId];
          final gotTimestamp = newDatetime is Timestamp;
          final datetimeChanged = gotTimestamp && newDatetime != _liveDatetimes[orderId];

          if (!statusChanged && !datetimeChanged) return;

          final becameTerminal = statusChanged &&
              (_doneStatuses.contains(newStatus) || _cancelStatuses.contains(newStatus));

          setState(() {
            if (statusChanged) _statuses[orderId] = newStatus;
            if (gotTimestamp) _liveDatetimes[orderId] = newDatetime;
            if (becameTerminal) _moveOrderToHistory(orderId);
          });

          if (becameTerminal) {
            _subscriptions[orderId]?.cancel();
            _subscriptions.remove(orderId);
          }
        }, onError: (e) {
          log('listen order $orderId error: $e');
        });
  }

  void _moveOrderToHistory(String orderId) {
    final idx = _activeOrders.indexWhere((o) => o.orderId == orderId);
    if (idx == -1) return;
    final order = _activeOrders.removeAt(idx);
    if (!_historyOrders.any((o) => o.orderId == orderId)) {
      _historyOrders.insert(0, order);
    }
  }

   String _statusLabel(String status) {
    return {
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
          'delivery_in_progress': 'กำลังจัดส่ง',
          'completed': 'เสร็จสิ้น',
          'cancelled': 'ยกเลิก',
        }[status] ??
        status;
  }

  Color _statusColor(String s) {
    if (_activeStatuses.contains(s)) return const Color(0xFF0EA5E9);
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

  static const _months = [
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

  String _formatDt(DateTime dt) {
    return '${dt.day} ${_months[dt.month]} ${dt.year + 543} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateOnly(DateTime dt) => '${dt.day} ${_months[dt.month]} ${dt.year + 543}';

  String _formatDate(Map<String, dynamic>? raw) {
    if (raw == null) return '-';
    final seconds = raw['_seconds'];
    if (seconds == null) return '-';
    return _formatDt(DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000));
  }

  String _formatTs(Timestamp ts) => _formatDt(ts.toDate());

  String _orderDatetimeText(StoreOrderItem order) {
    final live = _liveDatetimes[order.orderId];
    if (live != null) return _formatTs(live);
    return _formatDate(order.orderDatetime);
  }

  DateTime? _orderDateTime(StoreOrderItem order) {
    final live = _liveDatetimes[order.orderId];
    if (live != null) return live.toDate();
    final raw = order.orderDatetime;
    if (raw == null) return null;
    final seconds = raw['_seconds'];
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch((seconds as int) * 1000);
  }

  bool _matchesHistoryDate(StoreOrderItem order) {
    final selectedDate = _historySelectedDate;
    if (selectedDate == null) return true;
    final dt = _orderDateTime(order);
    if (dt == null) return false;
    return dt.year == selectedDate.year &&
        dt.month == selectedDate.month &&
        dt.day == selectedDate.day;
  }

  Future<void> _pickHistoryDate() async {
    final now = DateTime.now();
    final initialDate = _historySelectedDate ?? now;

    final result = await showCalendarDatePicker2Dialog(
      context: context,
      value: [initialDate.isAfter(now) ? now : initialDate],
      dialogSize: const Size(340, 430),
      borderRadius: BorderRadius.circular(24),
      dialogBackgroundColor: Colors.white,
      barrierColor: Colors.black.withOpacity(0.35),
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime(now.year - 5, 1, 1),
        lastDate: now,
        currentDate: now,
        firstDayOfWeek: 1,
        centerAlignModePicker: true,
        closeDialogOnCancelTapped: true,
        closeDialogOnOkTapped: true,
        selectedDayHighlightColor: _primary,
        controlsTextStyle: const TextStyle(
          color: _dark,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        dayTextStyle: const TextStyle(
          color: _dark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        selectedDayTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        todayTextStyle: const TextStyle(
          color: _primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        weekdayLabelTextStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        yearTextStyle: const TextStyle(
          color: _dark,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        selectedYearTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        cancelButtonTextStyle: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        okButtonTextStyle: const TextStyle(
          color: _primary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (result == null || result.isEmpty || result.first == null) return;

    final picked = result.first!;

    setState(() {
      _historySelectedDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _fetchHistory();
  }

  Future<void> _clearHistoryDate() async {
    setState(() {
      _historySelectedDate = null;
    });
    await _fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final anyLoading = _ordersLoading || _historyLoading;
    final anyError = _ordersError ?? _historyError;

    return Scaffold(
      backgroundColor: _bg,
      appBar: storeData == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(128),
              child: Column(
                children: [
                  StoreAppBar(
                    title: storeData?.storeName ?? '',
                    profileImage: storeData?.profileImage,
                    storeId: storeData?.storeId ?? '',
                  ),
                  Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tab,
                      indicatorColor: _primary,
                      indicatorWeight: 3,
                      labelColor: _primary,
                      unselectedLabelColor: Colors.black45,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      unselectedLabelStyle: const TextStyle(fontSize: 13),
                      tabs: const [
                        Tab(text: 'กำลังดำเนินการ'),
                        Tab(text: 'เสร็จสิ้น'),
                        Tab(text: 'ยกเลิก/ล้มเหลว'),
                      ],
                    ),
                  ),
                ],
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
          ? Center(
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
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      label: const Text('ลองใหม่'),
                    ),
                  ],
                ),
              ),
            )
          : anyLoading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : anyError != null
          ? Center(
              child: Text(
                anyError,
                style: TextStyle(color: Colors.red.shade400),
              ),
            )
          : TabBarView(
              controller: _tab,
              children: [
                _buildTab(_activeOrders, _activeStatuses, onRefresh: _fetchOrders),
                _buildHistoryTab(_doneStatuses),
                _buildHistoryTab(_cancelStatuses),
              ],
            ),
    );
  }

  Widget _buildTab(
    List<StoreOrderItem> source,
    Set<String> bucket, {
    required Future<void> Function() onRefresh,
  }) {
    final filtered = source
        .where((o) => bucket.contains(_statuses[o.orderId] ?? ''))
        .toList();

    return _buildOrderList(filtered, onRefresh);
  }

  Widget _buildHistoryTab(Set<String> bucket) {
    final filtered = _historyOrders
        .where((o) => bucket.contains(_statuses[o.orderId] ?? ''))
        .where(_matchesHistoryDate)
        .toList();

    return Column(
      children: [
        _historyDatePickerBar(),
        Expanded(child: _buildOrderList(filtered, _fetchHistory)),
      ],
    );
  }

  Widget _buildOrderList(
    List<StoreOrderItem> orders,
    Future<void> Function() onRefresh,
  ) {
    if (orders.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: _emptyView(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: orders.length,
        itemBuilder: (_, i) {
          final order = orders[i];
          return _card(order, _statuses[order.orderId] ?? '');
        },
      ),
    );
  }

  Widget _historyDatePickerBar() {
    final selectedDate = _historySelectedDate;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _pickHistoryDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: _primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.calendar_month_rounded,
                          color: _primary,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedDate == null
                                  ? 'เลือกวัน เดือน ปี'
                                  : _formatDateOnly(selectedDate),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _dark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedDate == null
                                  ? 'แตะเพื่อเปิดปฏิทิน'
                                  : 'แตะเพื่อเปลี่ยนวันที่',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.black45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (selectedDate != null) ...[
            const SizedBox(width: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _clearHistoryDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 48,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.redAccent,
                  ),
                ),
              ),
            ),
          ],
        ],
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

  Widget _card(StoreOrderItem order, String status) {
    final shortId =
        '#${order.orderId.substring(0, order.orderId.length.clamp(0, 8)).toUpperCase()}';
    final statusColor = _statusColor(status);
    final isActive = _activeStatuses.contains(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
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
          _divider,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                _infoRow(
                  Icons.access_time_rounded,
                  _orderDatetimeText(order),
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
          _divider,
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: status == 'completed'
                ? _actionButton(
                    label: 'ใบเสร็จ',
                    filled: true,
                    color: Colors.green,
                    onPressed: () => Get.to(
                      () => StoreCompletedScreen(orderId: order.orderId),
                    ),
                  )
                : _actionButton(
                    label: 'รายละเอียด',
                    filled: false,
                    color: _dark,
                    onPressed: () {
                      Get.to(
                        () => StoreOrderDetailScreen(orderId: order.orderId),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required bool filled,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: filled
          ? ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: _btnRadius),
                padding: _btnPadding,
              ),
              onPressed: onPressed,
              child: Text(label, style: _btnTextStyle),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: _btnRadius),
                padding: _btnPadding,
              ),
              onPressed: onPressed,
              child: Text(label, style: _btnTextStyle),
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
      tween: Tween(begin: _bright ? 0.3 : 1.0, end: _bright ? 1.0 : 0.3),
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
          decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}