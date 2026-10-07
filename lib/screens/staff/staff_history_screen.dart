import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/staff/req_updateorder_status_staff.dart';
import 'package:wash_and_dry/models/res/customer/staff/res_history_order_staff.dart';
import 'package:wash_and_dry/models/req/staff/req_update_status_staff.dart';
import 'package:wash_and_dry/screens/staff/staff_calculate_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstaff.dart';

void showStatusSnackbar({required String message, required bool success}) {
  Get.closeAllSnackbars();
  Get.snackbar(
    success ? 'สำเร็จ' : 'ผิดพลาด',
    message,
    snackPosition: SnackPosition.TOP,
    backgroundColor: Colors.white,
    colorText: Colors.black87,
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    borderRadius: 12,
    icon: Icon(
      success ? Icons.check_circle : Icons.error,
      color: success ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
    ),
    duration: const Duration(seconds: 3),
    isDismissible: true,
    snackStyle: SnackStyle.FLOATING,
    boxShadows: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

class StaffHistoryScreen extends StatefulWidget {
  const StaffHistoryScreen({super.key});
  @override
  State<StaffHistoryScreen> createState() => _StaffHistoryScreenState();
}

class _StaffHistoryScreenState extends State<StaffHistoryScreen>
    with SingleTickerProviderStateMixin {
  String _url = '';
  String _staffName = '';
  String? _profileImage;
  String? _staffId;
  late TabController _tabController;
  List<StaffOrder> _activeOrders = [];
  List<StaffOrder> _doneOrders = [];
  bool _isLoading = false;
  final Map<String, String> _lastKnownStatus = {};
  final Map<String, Duration> _remainingTimes = {};
  final Map<String, String> _countdownStatus = {};
  StreamSubscription<QuerySnapshot>? _statusSub;
  Timer? _countdownTimer;
  static const _activeStatuses = [
    'waiting_wash',
    'waiting_dry',
    'waiting_payment',
    'payment_completed',
    'washing',
    'drying',
  ];
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadInitial();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _tabController.dispose();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final config = await Configuration.getConfig();
      if (!mounted) return;
      setState(() => _url = config['apiEndpoint']?.toString() ?? '');
    } catch (_) {}
    final session = Session();
    final name = await session.getFullname();
    final image = await session.getProfileImage();
    final id = await session.getStaffId();
    if (!mounted) return;
    setState(() {
      _staffName = name ?? 'Staff';
      _profileImage = image;
      _staffId = id;
    });
    await _fetchOrders();
    _listenOrderStatus();
  }

  void _listenOrderStatus() {
    if (_staffId == null || _staffId!.isEmpty) return;
    final staffRef = FirebaseFirestore.instance
        .collection('laundry_staff')
        .doc(_staffId);
    _statusSub?.cancel();
    _statusSub = FirebaseFirestore.instance
        .collection('orders')
        .where('staff_id', isEqualTo: staffRef)
        .snapshots()
        .listen((snapshot) async {
          log('>>> SNAPSHOT DOCS COUNT: ${snapshot.docs.length}');
          bool shouldRefresh = false;
          for (final doc in snapshot.docs) {
            final data = doc.data();
            final status = data['status']?.toString();
            log('>>> DOC ${doc.id} status=$status');
            if (status == null) continue;
            final previousStatus = _lastKnownStatus[doc.id];
            final statusChanged = previousStatus != status;
            _lastKnownStatus[doc.id] = status;
            if (statusChanged || status == 'payment_completed') {
              shouldRefresh = true;
            }
            if (status != 'washing' && status != 'drying') {
              _remainingTimes.remove(doc.id);
              _countdownStatus.remove(doc.id);
            }
          }
          log('>>> SHOULD REFRESH: $shouldRefresh');
          if (shouldRefresh) {
            await _fetchOrders();
          }
        }, onError: (e) => log('>>> STATUS STREAM ERROR: $e'));
  }

  Future<void> _fetchOrders() async {
    if (_staffId == null || _url.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('$_url/order/staff/historynow/$_staffId');
      log('>>> URL: $uri');
      final res = await http.get(uri);
      log('>>> STATUS: ${res.statusCode}');
      if (!mounted) return;
      if (res.statusCode == 200) {
        final response = staffOrderListResponseFromJson(res.body);
        setState(() {
          _activeOrders = response.data
              .where((o) => _activeStatuses.contains(o.status))
              .toList();
          _doneOrders = response.data
              .where(
                (o) => const [
                  'waiting_delivery',
                  'delivery_heading_to_shop',
                  'delivery_pickup_completed',
                  'delivery_in_progress',
                  'completed',
                ].contains(o.status),
              )
              .toList();
        });
        for (final o in response.data) {
          _lastKnownStatus[o.id] = o.status;
        }
        _syncCountdowns(response.data);
      }
    } catch (e) {
      log('>>> ERROR: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _syncCountdowns(List<StaffOrder> orders) {
    final activeOrderIds = <String>{};
    for (final order in orders) {
      final isWashing = order.status == 'washing';
      final isDrying = order.status == 'drying';
      if (!isWashing && !isDrying) {
        _remainingTimes.remove(order.id);
        _countdownStatus.remove(order.id);
        continue;
      }
      activeOrderIds.add(order.id);
      final workMinutes = isWashing
          ? order.washer?.workMinutes
          : order.dryer?.workMinutes;
      if (workMinutes == null || workMinutes <= 0) {
        _remainingTimes[order.id] = Duration.zero;
        _countdownStatus[order.id] = order.status;
        continue;
      }
      final isNewProcess = _countdownStatus[order.id] != order.status;
      if (isNewProcess || !_remainingTimes.containsKey(order.id)) {
        _remainingTimes[order.id] = Duration(minutes: workMinutes.toInt());
        _countdownStatus[order.id] = order.status;
      }
    }
    final removedOrderIds = _remainingTimes.keys
        .where((id) => !activeOrderIds.contains(id))
        .toList();
    for (final id in removedOrderIds) {
      _remainingTimes.remove(id);
      _countdownStatus.remove(id);
    }
    if (_remainingTimes.isNotEmpty) {
      _startCountdownTimer();
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  void _startCountdownTimer() {
    if (_countdownTimer?.isActive ?? false) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      bool hasRunningCountdown = false;
      final updated = <String, Duration>{};
      for (final entry in _remainingTimes.entries) {
        final next = entry.value - const Duration(seconds: 1);
        if (next.isNegative || next == Duration.zero) {
          updated[entry.key] = Duration.zero;
        } else {
          updated[entry.key] = next;
          hasRunningCountdown = true;
        }
      }
      setState(() {
        _remainingTimes
          ..clear()
          ..addAll(updated);
      });
      if (!hasRunningCountdown) {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBarStaff(
        staffName: _staffName,
        staffId: _staffId ?? '',
        profileImage: _profileImage,
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: _isLoading && _activeOrders.isEmpty && _doneOrders.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(_activeOrders, isDone: false),
                      _buildOrderList(_doneOrders, isDone: true),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: TabBar(
      controller: _tabController,
      indicatorColor: const Color(0xFF1E88E5),
      indicatorWeight: 3,
      labelColor: const Color(0xFF1E88E5),
      unselectedLabelColor: Colors.grey,
      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontSize: 14),
      dividerColor: Colors.transparent,
      tabs: const [
        Tab(text: 'กำลังดำเนินการ'),
        Tab(text: 'ดำเนินการเสร็จสิ้น'),
      ],
    ),
  );
  Widget _buildOrderList(List<StaffOrder> orders, {required bool isDone}) {
    if (orders.isEmpty) {
      return const Center(child: Text('ไม่มีออเดอร์'));
    }
    return RefreshIndicator(
      onRefresh: _fetchOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (_, i) => _OrderCard(
          order: orders[i],
          isDone: isDone,
          onRefresh: _fetchOrders,
          url: _url,
          staffId: _staffId ?? '',
          remainingTime: _remainingTimes[orders[i].id],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final StaffOrder order;
  final bool isDone;
  final VoidCallback onRefresh;
  final String url;
  final String staffId;
  final Duration? remainingTime;
  const _OrderCard({
    required this.order,
    required this.isDone,
    required this.onRefresh,
    required this.url,
    required this.staffId,
    required this.remainingTime,
  });
  bool get _needsWash =>
      order.serviceType == 'wash' || order.serviceType == 'wash_dry';
  bool get _needsDry =>
      order.serviceType == 'dry' || order.serviceType == 'wash_dry';
  bool get _isWaitingForCalculate =>
      order.status == 'waiting_wash' || order.status == 'waiting_dry';
  bool get _isPaymentCompleted => order.status == 'payment_completed';
  bool get _isWashing => order.status == 'washing';
  bool get _isRunning => order.status == 'washing' || order.status == 'drying';
  bool get _canUpdate =>
      !isDone &&
      order.status != 'waiting_payment' &&
      order.status != 'payment_completed';
  bool get _showStartDry => _isWashing && order.serviceType == 'wash_dry';
  String get _startActionLabel =>
      order.serviceType == 'dry' ? 'เริ่มอบ' : 'เริ่มซัก';
  String _statusText(String s) => switch (s) {
    'waiting_wash' => 'รอซัก',
    'waiting_dry' => 'รออบ',
    'waiting_payment' => 'รอชำระเงิน',
    'payment_completed' => 'ชำระเงินแล้ว',
    'washing' => 'กำลังซัก',
    'drying' => 'กำลังอบ',
    'waiting_delivery' => 'รอพนักงานรับส่ง',
    'delivery_heading_to_shop' => 'พนักงานรับส่งกำลังมารับผ้า',
    'delivery_pickup_completed' => 'พนักงานรับส่งรับผ้าแล้ว',
    'delivery_in_progress' => 'กำลังจัดส่ง',
    'completed' => 'จัดส่งสำเร็จ',
    _ => s,
  };
  Color _statusColor(String s) => switch (s) {
    'waiting_wash' => Colors.orange,
    'waiting_dry' => Colors.orange,
    'waiting_payment' => Colors.red,
    'payment_completed' => Colors.green,
    'washing' => Colors.blue,
    'drying' => Colors.blue,
    'waiting_delivery' => Colors.green,
    'delivery_heading_to_shop' => Colors.blue,
    'delivery_pickup_completed' => Colors.blue,
    'delivery_in_progress' => Colors.blue,
    'completed' => Colors.green,
    _ => Colors.grey,
  };
  String _serviceText(String t) => switch (t) {
    'wash' => 'ซักอย่างเดียว',
    'dry' => 'อบอย่างเดียว',
    'wash_dry' => 'ซัก + อบ',
    _ => t,
  };
  void _showUpdateBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _UpdateStatusSheet(
        order: order,
        url: url,
        staffId: staffId,
        onSuccess: onRefresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderRow(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (order.customer != null)
                        _buildCustomerInfo(order.customer!),
                      const SizedBox(height: 8),
                      _buildServiceRow(),
                      _buildMachineInfo(),
                      if (order.note != null && order.note!.isNotEmpty)
                        _buildNoteRow(order.note!),
                    ],
                  ),
                ),
                if (_isRunning) ...[
                  const SizedBox(width: 12),
                  _buildCountdown(),
                ],
              ],
            ),
            const SizedBox(height: 12),
            _buildActionButton(context),
            _buildStatusBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        '#${order.id}'.substring(0, 10).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _statusColor(order.status),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _statusText(order.status),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    ],
  );
  Widget _buildCustomerInfo(dynamic customer) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(customer.name, style: const TextStyle(fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.location_on_outlined,
              size: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              order.address ?? '-',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                height: 1.3,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Row(
        children: [
          const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Text(
            customer.phone,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    ],
  );
  Widget _buildServiceRow() => Row(
    children: [
      const Icon(
        Icons.local_laundry_service_outlined,
        size: 16,
        color: Colors.blue,
      ),
      const SizedBox(width: 6),
      Text(
        'บริการ: ${_serviceText(order.serviceType)}',
        style: const TextStyle(fontSize: 13),
      ),
    ],
  );
  Widget _buildMachineInfo() {
    final washerName = _needsWash ? order.washer?.name : null;
    final dryerName = _needsDry ? order.dryer?.name : null;
    if (washerName == null && dryerName == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          if (washerName != null)
            _machineChip(
              label: 'เครื่องซัก',
              value: washerName,
              color: Colors.blue,
            ),
          if (dryerName != null)
            _machineChip(
              label: 'เครื่องอบ',
              value: dryerName,
              color: Colors.orange,
            ),
        ],
      ),
    );
  }

  Widget _machineChip({
    required String label,
    required String value,
    required Color color,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(
      '$label: $value',
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
    ),
  );
  Widget _buildNoteRow(String note) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.notes_outlined, size: 15, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'หมายเหตุ: $note',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
  Widget _buildActionButton(BuildContext context) {
    if (_isWaitingForCalculate) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Get.to(
              () => StaffCalculateScreen(order: order.toJson()),
            )?.then((_) => onRefresh());
          },
          label: const Text('คำนวณราคา', style: TextStyle(color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    if (_isPaymentCompleted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _callStartPaid(context),
          icon: const Icon(
            Icons.play_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          label: Text(
            _startActionLabel,
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    if (_showStartDry) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _showStartDryDialog,
          label: const Text(
            'ซักเสร็จแล้ว เริ่มอบ',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    if (_canUpdate) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _showUpdateBottomSheet(context),
          icon: const Icon(
            Icons.check_circle_outline,
            color: Colors.white,
            size: 18,
          ),
          label: const Text(
            'เสร็จสิ้น พร้อมส่ง',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildCountdown() {
    final totalSeconds = (remainingTime?.inSeconds ?? 0).clamp(0, 999999);
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    final timeText =
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
    final isFinished = totalSeconds == 0;
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFinished
                ? 'ครบเวลา'
                : order.status == 'washing'
                ? 'เวลาซัก'
                : 'เวลาอบ',
            style: TextStyle(
              fontSize: 11,
              color: isFinished ? Colors.red.shade700 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            timeText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isFinished ? Colors.red.shade700 : const Color(0xFF222222),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    if (order.status == 'waiting_payment') {
      return _banner(text: 'รอลูกค้าชำระเงิน', color: Colors.red);
    }
    if (order.status == 'payment_completed') {
      return _banner(text: 'ลูกค้าชำระเงินแล้ว', color: Colors.green);
    }
    return const SizedBox.shrink();
  }

  Widget _banner({required String text, required Color color}) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontSize: 13),
    ),
  );
  Future<void> _callStartPaid(BuildContext context) async {
    try {
      final res = await http.put(
        Uri.parse('$url/order/staff/start_paid/${order.id}'),
        headers: {'Content-Type': 'application/json'},
        body: '{"staff_id":"$staffId"}',
      );
      final body = updateStatusResponseFromJson(res.body);
      final ok = res.statusCode == 200;
      if (ok) {
        onRefresh();
      }
      showStatusSnackbar(message: body.message, success: ok);
    } catch (e) {
      showStatusSnackbar(message: 'เกิดข้อผิดพลาด: $e', success: false);
    }
  }

  void _showStartDryDialog() {
    final dryer = order.dryer;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(0xFFE6F3FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.local_laundry_service_rounded,
                        color: Color(0xFF0593FF),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เริ่มอบผ้า',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ซักเสร็จแล้ว พร้อมเริ่มอบ',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (dryer == null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ไม่พบข้อมูลเครื่องอบ',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dryer.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _statColumn(
                                label: 'ความจุ',
                                value: dryer.capacity != null
                                    ? '${dryer.capacity} kg'
                                    : '-',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 30,
                              color: Colors.grey.shade200,
                            ),
                            Expanded(
                              child: _statColumn(
                                label: 'เวลาอบ',
                                value: dryer.workMinutes != null
                                    ? '${dryer.workMinutes} นาที'
                                    : '-',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          await _callStartDry();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0593FF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'เริ่มอบผ้า',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Get.back(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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

  Widget _statColumn({required String label, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade900,
          ),
        ),
      ],
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade100),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: Colors.orange),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _callStartDry() async {
    try {
      final res = await http.put(
        Uri.parse('$url/order/staff/update/status/${order.id}'),
        headers: {'Content-Type': 'application/json'},
        body: updateStatusRequestToJson(
          UpdateStatusRequest(staffId: staffId, status: 'drying'),
        ),
      );
      final response = updateStatusResponseFromJson(res.body);
      final success = res.statusCode == 200;
      if (success) onRefresh();
      showStatusSnackbar(message: response.message, success: success);
    } catch (e) {
      showStatusSnackbar(message: 'เกิดข้อผิดพลาด: $e', success: false);
    }
  }
}

class _UpdateStatusSheet extends StatefulWidget {
  final StaffOrder order;
  final String url;
  final String staffId;
  final VoidCallback onSuccess;
  const _UpdateStatusSheet({
    required this.order,
    required this.url,
    required this.staffId,
    required this.onSuccess,
  });
  @override
  State<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<_UpdateStatusSheet> {
  bool _isSubmitting = false;
  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final res = await http.put(
        Uri.parse('${widget.url}/order/staff/update/status/${widget.order.id}'),
        headers: {'Content-Type': 'application/json'},
        body: updateStatusRequestToJson(
          UpdateStatusRequest(
            staffId: widget.staffId,
            status: 'waiting_delivery',
          ),
        ),
      );
      final response = updateStatusResponseFromJson(res.body);
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context);
        widget.onSuccess();
        showStatusSnackbar(message: response.message, success: true);
      } else {
        showStatusSnackbar(message: response.message, success: false);
      }
    } catch (e) {
      if (mounted) {
        showStatusSnackbar(message: 'เกิดข้อผิดพลาด: $e', success: false);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'เสร็จสิ้น / พร้อมส่ง',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 4),
          const Text(
            'ยืนยันการเสร็จสิ้นงาน',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'ยืนยันเสร็จสิ้น',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
