import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/rider/res_work_of_rider.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarrider.dart';

const _blue = Color(0xFF0593FF);
const _green = Color(0xFF16A34A);
const _surface = Color(0xFFF9FAFB);
const _border = Color(0xFFE5E7EB);
const _textPrimary = Color(0xFF111827);
const _textSecondary = Color(0xFF6B7280);

abstract class _S {
  static const pickedUp = 'pickup_in_progress';
  static const pickupCompleted = 'pickup_completed';
  static const arrivedAtShop = 'arrived_at_shop';
  static const deliveryHeadingToShop = 'delivery_heading_to_shop';
  static const deliveryPickupCompleted = 'delivery_pickup_completed';
  static const delivering = 'delivery_in_progress';
  static const waitingWash = 'waiting_wash';
  static const waitingDry = 'waiting_dry';
  static const completed = 'completed';
}

class _StatusStep {
  final String label;
  final String buttonLabel;
  final String successMessage;
  final String? nextStatus;
  final bool needsPhoto;

  const _StatusStep({
    required this.label,
    required this.buttonLabel,
    required this.successMessage,
    this.nextStatus,
    this.needsPhoto = false,
  });
}

const _statusSteps = <String, _StatusStep>{
  _S.pickedUp: _StatusStep(
    label: 'กำลังไปรับผ้า',
    buttonLabel: 'รับผ้าจากลูกค้าแล้ว',
    successMessage: 'รับผ้าจากลูกค้าเรียบร้อยแล้ว',
    nextStatus: _S.pickupCompleted,
    needsPhoto: true,
  ),
  _S.pickupCompleted: _StatusStep(
    label: 'รับผ้าแล้ว กำลังไปร้าน',
    buttonLabel: 'ถึงร้านแล้ว',
    successMessage: 'ถึงร้านเรียบร้อยแล้ว',
    nextStatus: _S.arrivedAtShop,
  ),
  _S.arrivedAtShop: _StatusStep(
    label: 'ถึงร้านแล้ว',
    buttonLabel: 'เสร็จ',
    successMessage: 'ส่งผ้าเข้ารอการคำนวณเรียบร้อยแล้ว',
  ),
  _S.deliveryHeadingToShop: _StatusStep(
    label: 'กำลังไปที่ร้าน',
    buttonLabel: 'รับผ้าที่ร้านแล้ว',
    successMessage: 'รับผ้าที่ร้านเรียบร้อยแล้ว',
    nextStatus: _S.deliveryPickupCompleted,
  ),
  _S.deliveryPickupCompleted: _StatusStep(
    label: 'รับผ้าที่ร้านแล้ว',
    buttonLabel: 'เริ่มจัดส่ง',
    successMessage: 'เริ่มจัดส่งเรียบร้อยแล้ว',
    nextStatus: _S.delivering,
  ),
  _S.delivering: _StatusStep(
    label: 'กำลังจัดส่ง',
    buttonLabel: 'ส่งผ้าถึงลูกค้าแล้ว',
    successMessage: 'ส่งผ้าถึงลูกค้าเรียบร้อยแล้ว',
    nextStatus: _S.completed,
    needsPhoto: true,
  ),
};

String _serviceLabel(String? type) => switch (type) {
  'wash' => 'ซักผ้าอย่างเดียว',
  'dry' => 'อบผ้าอย่างเดียว',
  'wash_dry' => 'ซัก + อบ',
  _ => type ?? '-',
};

double? _calcDistance(
  double? lat1,
  double? lng1,
  double? lat2,
  double? lng2,
) {
  if (lat1 == null || lng1 == null || lat2 == null || lng2 == null) {
    return null;
  }

  const earthRadiusKm = 6371.0;

  double toRad(double deg) => deg * pi / 180;

  final dLat = toRad(lat2 - lat1);
  final dLng = toRad(lng2 - lng1);

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(toRad(lat1)) *
          cos(toRad(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);

  return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}

Widget _chip(
  String label,
  Color color, {
  bool small = false,
  bool isService = false,
}) {
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: small ? 8 : 10,
      vertical: small ? 3 : 4,
    ),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isService) ...[
          Icon(Icons.local_laundry_service, size: 14, color: color),
          const SizedBox(width: 4),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: TextStyle(
              color: color,
              fontSize: small ? 11 : 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatOrderDateTime(DateTime? dateTime) {
  if (dateTime == null) return '-';

  final d = dateTime.toLocal();

  return '${d.day}/${d.month}/${d.year + 543} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')} น.';
}

Widget _addressRow(String text) {
  return Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: _textSecondary,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _customerRow(
  String? name,
  String? phone,
  String? profileImage,
) {
  if (name == null) return const SizedBox.shrink();

  return Row(
    children: [
      CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFE8F3FF),
        backgroundImage:
            profileImage != null ? NetworkImage(profileImage) : null,
        child: profileImage == null
            ? Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: _blue,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              )
            : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: _textPrimary,
              ),
            ),
            if (phone != null)
              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 12,
                    color: _textSecondary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    phone,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ],
  );
}

Widget _cardShell({
  required Widget child,
  required Color leftColor,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: leftColor,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: child,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _emptyState(
  IconData icon,
  String label, {
  Widget? action,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 52, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: _textSecondary,
            fontSize: 14,
          ),
        ),
        if (action != null) ...[
          const SizedBox(height: 16),
          action,
        ],
      ],
    ),
  );
}

Widget _step(String label, bool done) {
  return Column(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: done ? _green : Colors.grey.shade100,
        child: Icon(
          Icons.check,
          size: 16,
          color: done ? Colors.white : Colors.grey.shade300,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: done ? _green : Colors.grey.shade400,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

Widget _line(bool done) {
  return Expanded(
    child: Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: done ? _green : _border,
    ),
  );
}

Widget _progressBar(String status) {
  const deliveryStatuses = [
    _S.deliveryHeadingToShop,
    _S.deliveryPickupCompleted,
    _S.delivering,
    _S.completed,
  ];

  if (deliveryStatuses.contains(status)) {
    final pickedUpDone =
        status == _S.deliveryPickupCompleted ||
        status == _S.delivering ||
        status == _S.completed;

    final deliveringDone =
        status == _S.delivering ||
        status == _S.completed;

    final finished = status == _S.completed;

    return Row(
      children: [
        _step('รับงาน', true),
        _line(pickedUpDone),
        _step('รับผ้าที่ร้าน', pickedUpDone),
        _line(deliveringDone),
        _step('ส่งผ้า', deliveringDone),
        _line(finished),
        _step('เสร็จ', finished),
      ],
    );
  }

  final pickedUpDone =
      status == _S.pickupCompleted ||
      status == _S.arrivedAtShop;

  final arrivedDone = status == _S.arrivedAtShop;

  return Row(
    children: [
      _step('รับงาน', true),
      _line(true),
      _step('รับผ้า', pickedUpDone),
      _line(pickedUpDone),
      _step('ถึงร้าน', arrivedDone),
      _line(arrivedDone),
      _step('เสร็จ', arrivedDone),
    ],
  );
}

Widget _successDialog(String message) {
  return Dialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: _green,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'สำเร็จ!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: _textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: Get.back,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'ตกลง',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ═══════════════════════════ Screen ═══════════════════════════

class RiderOrdersScreen extends StatefulWidget {
  const RiderOrdersScreen({super.key});

  @override
  State<RiderOrdersScreen> createState() => _RiderOrdersScreenState();
}

class _RiderOrdersScreenState extends State<RiderOrdersScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(
    length: 2,
    vsync: this,
  );

  String _riderName = '';
  String? _profileImage;
  String? _riderId;
  String? _apiUrl;

  @override
  void initState() {
    super.initState();
    _loadRiderInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRiderInfo() async {
    final session = Session();

    final results = await Future.wait([
      session.getFullname(),
      session.getProfileImage(),
      session.getRiderId(),
      Configuration.getConfig()
          .then((c) => c['apiEndpoint']?.toString() ?? '')
          .catchError((_) => ''),
    ]);

    if (!mounted) return;

    setState(() {
      _riderName = (results[0] as String?) ?? 'Rider';
      _profileImage = results[1] as String?;
      _riderId = results[2] as String?;
      _apiUrl = results[3] as String?;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ready =
        _riderId != null &&
        (_apiUrl?.isNotEmpty ?? false);

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBarRider(
        riderName: _riderName,
        riderId: _riderId ?? '',
        profileImage: _profileImage,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: _blue,
              unselectedLabelColor: _textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              indicatorColor: _blue,
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(text: 'กำลังดำเนินการ'),
                Tab(text: 'ดำเนินการเสร็จสิ้น'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: ready
                  ? [
                      _ActiveTab(
                        riderId: _riderId!,
                        apiUrl: _apiUrl!,
                      ),
                      _CompletedTab(
                        riderId: _riderId!,
                        apiUrl: _apiUrl!,
                      ),
                    ]
                  : List.generate(
                      2,
                      (_) => const Center(
                        child: CircularProgressIndicator(
                          color: _blue,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Date filter model ─────────────────────────

const _thMonths = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

const _thMonthsShort = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

class _DateFilter {
  final int year; // ค.ศ.
  final int month; // 1-12
  final int? day; // null = กรองรายเดือน

  const _DateFilter({
    required this.year,
    required this.month,
    this.day,
  });

  bool get isMonth => day == null;

  String get label => isMonth
      ? '${_thMonths[month - 1]} ${year + 543}'
      : '$day ${_thMonthsShort[month - 1]} ${year + 543}';
}

// ───────────────────────── Status label/color ─────────────────────────

({String label, Color color}) _doneStatusInfo(String status) {
  switch (status) {
    case 'completed':
      return (label: 'เสร็จสิ้น', color: _green);
    case 'cancelled':
      return (label: 'ยกเลิก', color: Colors.red);
    case 'waiting_payment':
      return (label: 'รอชำระเงิน', color: Colors.orange);
    case 'payment_completed':
      return (label: 'ชำระเงินแล้ว', color: _green);
    case 'waiting_machine':
      return (label: 'รอเครื่อง', color: _blue);
    case 'waiting_wash':
      return (label: 'รอซัก', color: _blue);
    case 'washing':
      return (label: 'กำลังซัก', color: _blue);
    case 'waiting_dry':
      return (label: 'รออบ', color: _blue);
    case 'drying':
      return (label: 'กำลังอบ', color: _blue);
    default:
      return (label: status, color: _textSecondary);
  }
}

// ═══════════════════════════ Completed tab ═══════════════════════════

class _CompletedTab extends StatefulWidget {
  final String riderId;
  final String apiUrl;

  const _CompletedTab({
    required this.riderId,
    required this.apiUrl,
  });

  @override
  State<_CompletedTab> createState() => _CompletedTabState();
}

class _CompletedTabState extends State<_CompletedTab> {
  List<WorkOfRider> _orders = [];
  bool _loading = true;
  String? _error;
  _DateFilter? _filter;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final reqId = ++_requestId;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final params = <String, String>{'mode': 'done'};

      final f = _filter;
      if (f != null) {
        params['year'] = f.year.toString();
        params['month'] = f.month.toString();
        if (f.day != null) params['day'] = f.day.toString();
      }

      final uri = Uri.parse(
        '${widget.apiUrl}/order/rider/${widget.riderId}',
      ).replace(queryParameters: params);

      final res = await http.get(uri);

      if (!mounted || reqId != _requestId) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['ok'] == true) {
        final list = (body['data'] as List)
            .map((e) => WorkOfRider.fromJson(e as Map<String, dynamic>))
            .toList()
          ..sort((a, b) {
            final da = a.orderDatetime;
            final db = b.orderDatetime;
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return db.compareTo(da); // ใหม่สุดก่อน
          });

        setState(() {
          _orders = list;
          _loading = false;
        });
      } else {
        setState(() {
          _orders = [];
          _error = body['message'] as String? ?? 'เกิดข้อผิดพลาด';
          _loading = false;
        });
      }
    } catch (e) {
      log('fetchDoneOrders: $e');

      if (!mounted || reqId != _requestId) return;

      setState(() {
        _orders = [];
        _error = 'ไม่สามารถเชื่อมต่อได้';
        _loading = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final result = await showDialog<_DateFilter>(
      context: context,
      builder: (_) => _DateFilterDialog(initial: _filter),
    );

    if (result == null) return;

    setState(() => _filter = result);
    _fetch();
  }

  void _clearFilter() {
    setState(() => _filter = null);
    _fetch();
  }

  Widget _filterBar() {
    final hasFilter = _filter != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: hasFilter
                    ? _blue.withOpacity(0.08)
                    : const Color(0xFFF1F3F6),
                borderRadius: BorderRadius.circular(20),
                border: hasFilter
                    ? Border.all(color: _blue.withOpacity(0.4))
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 16,
                    color: _blue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    hasFilter ? _filter!.label : 'เลือกวันที่',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasFilter ? _blue : _textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _clearFilter,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F3F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 16,
                  color: _textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderCard(WorkOfRider order) {
    final info = _doneStatusInfo(order.status);

    final shortId = order.id
        .substring(0, order.id.length.clamp(0, 8))
        .toUpperCase();

    return _cardShell(
      leftColor: info.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$shortId',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              _chip(info.label, info.color),
            ],
          ),
          const SizedBox(height: 12),
          _customerRow(
            order.customer?.name,
            order.customer?.phone,
            order.customer?.profileImage,
          ),
          if (order.address != null) _addressRow(order.address!),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(
                _serviceLabel(order.serviceType),
                _textSecondary,
                small: true,
                isService: true,
              ),
              if (order.orderDatetime != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatOrderDateTime(order.orderDatetime),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = const Center(
        child: CircularProgressIndicator(color: _blue),
      );
    } else if (_error != null || _orders.isEmpty) {
      content = _emptyState(
        _error != null ? Icons.error_outline : Icons.inbox_outlined,
        _error ??
            (_filter != null
                ? 'ไม่พบงานในช่วงที่เลือก'
                : 'ยังไม่มีงานที่ทำเสร็จแล้ว'),
        action: TextButton.icon(
          onPressed: _fetch,
          icon: const Icon(Icons.refresh, size: 18, color: _blue),
          label: const Text(
            'โหลดใหม่',
            style: TextStyle(color: _blue),
          ),
        ),
      );
    } else {
      content = RefreshIndicator(
        color: _blue,
        onRefresh: _fetch,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _orders.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
        ),
      );
    }

    return Column(
      children: [
        _filterBar(),
        Expanded(child: content),
      ],
    );
  }
}

// ───────────────────────── Date filter dialog ─────────────────────────

class _DateFilterDialog extends StatefulWidget {
  final _DateFilter? initial;

  const _DateFilterDialog({this.initial});

  @override
  State<_DateFilterDialog> createState() => _DateFilterDialogState();
}

class _DateFilterDialogState extends State<_DateFilterDialog> {
  static const _weekdays = ['จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส', 'อา'];
  static const _disabled = Color(0xFFC9CED6);
  static const _segmentBg = Color(0xFFEEF2F9);

  final DateTime _now = DateTime.now();

  late bool _isMonth;
  late int _year;
  late int _month;
  late int _day;

  @override
  void initState() {
    super.initState();

    final f = widget.initial;

    _isMonth = f?.isMonth ?? false;
    _year = f?.year ?? _now.year;
    _month = f?.month ?? _now.month;
    _day = f?.day ?? _now.day;

    _clamp();
  }

  int _daysInMonth(int y, int m) => DateTime(y, m + 1, 0).day;

  bool _isFutureMonth(int y, int m) =>
      y > _now.year || (y == _now.year && m > _now.month);

  bool _isFutureDay(int y, int m, int d) =>
      _isFutureMonth(y, m) ||
      (y == _now.year && m == _now.month && d > _now.day);


  void _clamp() {
    if (_year > _now.year) _year = _now.year;
    if (_isFutureMonth(_year, _month)) _month = _now.month;

    final maxDay = _daysInMonth(_year, _month);
    if (_day > maxDay) _day = maxDay;
    if (_isFutureDay(_year, _month, _day)) _day = _now.day;
  }

  bool get _canGoNext => _isMonth
      ? _year < _now.year
      : !_isFutureMonth(
          _month == 12 ? _year + 1 : _year,
          _month == 12 ? 1 : _month + 1,
        );

  void _prev() {
    setState(() {
      if (_isMonth) {
        _year--;
      } else if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
      _clamp();
    });
  }

  void _next() {
    if (!_canGoNext) return;

    setState(() {
      if (_isMonth) {
        _year++;
      } else if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
      _clamp();
    });
  }

 

  Widget _segment(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF1E88E5) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _monthDropdown() {
    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _month,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
        items: List.generate(12, (i) {
          final m = i + 1;
          final disabled = _isFutureMonth(_year, m);

          return DropdownMenuItem<int>(
            value: m,
            enabled: !disabled,
            child: Text(
              _thMonths[i],
              style: TextStyle(color: disabled ? _disabled : _textPrimary),
            ),
          );
        }),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _month = v;
            _clamp();
          });
        },
      ),
    );
  }

  Widget _yearDropdown() {
    final years = List.generate(6, (i) => _now.year - i); // ย้อนหลัง 6 ปี

    return DropdownButtonHideUnderline(
      child: DropdownButton<int>(
        value: _year,
        isDense: true,
        icon: const Icon(Icons.arrow_drop_down, color: _textSecondary),
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
        items: years
            .map(
              (y) => DropdownMenuItem<int>(
                value: y,
                child: Text('${y + 543}'),
              ),
            )
            .toList(),
        onChanged: (v) {
          if (v == null) return;
          setState(() {
            _year = v;
            _clamp();
          });
        },
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        IconButton(
          onPressed: _prev,
          icon: const Icon(Icons.chevron_left),
          color: _textSecondary,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isMonth) ...[
                _monthDropdown(),
                const SizedBox(width: 12),
              ],
              _yearDropdown(),
            ],
          ),
        ),
        IconButton(
          onPressed: _canGoNext ? _next : null,
          icon: const Icon(Icons.chevron_right),
          color: _textSecondary,
          disabledColor: _disabled,
        ),
      ],
    );
  }

  Widget _dayGrid() {
    final offset = DateTime(_year, _month, 1).weekday - 1; // จันทร์ = 0
    final total = _daysInMonth(_year, _month);

    return Column(
      children: [
        Row(
          children: _weekdays
              .map(
                (w) => Expanded(
                  child: Center(
                    child: Text(
                      w,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8FA3C8),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 42, // 6 แถวคงที่ ความสูงไม่กระโดด
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 0,
          ),
          itemBuilder: (_, index) {
            final day = index - offset + 1;

            if (day < 1 || day > total) return const SizedBox.shrink();

            final disabled = _isFutureDay(_year, _month, day);
            final selected = day == _day;

            return GestureDetector(
              onTap: disabled ? null : () => setState(() => _day = day),
              behavior: HitTestBehavior.opaque,
              child: Center(
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF1E88E5)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? Colors.white
                          : (disabled ? _disabled : _textPrimary),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _monthGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemBuilder: (_, i) {
        final m = i + 1;
        final disabled = _isFutureMonth(_year, m);
        final selected = m == _month;

        return GestureDetector(
          onTap: disabled ? null : () => setState(() => _month = m),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF1E88E5)
                  : const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _thMonthsShort[i],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : (disabled ? _disabled : _textPrimary),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // toggle รายวัน / รายเดือน
              Container(
                height: 46,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: _segmentBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _segment('รายวัน', !_isMonth, () {
                      setState(() => _isMonth = false);
                    }),
                    _segment('รายเดือน', _isMonth, () {
                      setState(() => _isMonth = true);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _header(),
              const SizedBox(height: 8),
              if (_isMonth) _monthGrid() else _dayGrid(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'ยกเลิก',
                      style: TextStyle(
                        color: _textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _DateFilter(
                        year: _year,
                        month: _month,
                        day: _isMonth ? null : _day,
                      ),
                    ),
                    child: const Text(
                      'ตกลง',
                      style: TextStyle(
                        color: Color(0xFF1E88E5),
                        fontWeight: FontWeight.w700,
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
}


class _ActiveTab extends StatefulWidget {
  final String riderId;
  final String apiUrl;

  const _ActiveTab({
    required this.riderId,
    required this.apiUrl,
  });

  @override
  State<_ActiveTab> createState() => _ActiveTabState();
}

class _ActiveTabState extends State<_ActiveTab> {
  List<WorkOfRider> _orders = [];
  bool _loading = true;
  bool _fetching = false;
  String? _error;
  double? _lat;
  double? _lng;

  final Map<String, File?> _photoByOrderId = {};
  final Map<String, bool> _uploadingByOrderId = {};

  @override
  void initState() {
    super.initState();
    _fetchOrders();
    _resolveLocation();
  }

  Future<void> _resolveLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        _lat = lastKnown.latitude;
        _lng = lastKnown.longitude;

        if (mounted) {
          _recomputeDistances();
        }
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lat = current.latitude;
      _lng = current.longitude;

      if (mounted) {
        _recomputeDistances();
      }
    } catch (e) {
      log('resolveLocation: $e');
    }
  }

  void _recomputeDistances() {
    if (_orders.isEmpty) return;

    setState(() {
      _orders = _orders.map((order) {
        final km = _calcDistance(
          _lat,
          _lng,
          order.addressLat,
          order.addressLng,
        );

        return order.copyWith(
          distanceKm:
              km != null ? double.parse(km.toStringAsFixed(1)) : null,
        );
      }).toList();
    });
  }

  Future<void> _fetchOrders() async {
    if (_fetching) return;

    _fetching = true;

    if (!mounted) return;

    setState(() {
      _loading = _orders.isEmpty;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse(
          '${widget.apiUrl}/order/rider/${widget.riderId}',
        ),
      );

      if (!mounted) return;

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode == 200 && body['ok'] == true) {
        setState(() {
          _orders = (body['data'] as List)
              .map(
                (e) => WorkOfRider.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList();
        });

        _recomputeDistances();
      } else {
        setState(() {
          _error = body['message'] as String? ?? 'ไม่พบออเดอร์';
        });
      }
    } catch (e) {
      log('fetchOrders: $e');

      if (mounted) {
        setState(() {
          _error = 'ไม่สามารถเชื่อมต่อได้';
        });
      }
    } finally {
      _fetching = false;

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(String orderId) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(16),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: _blue,
              ),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(
                ctx,
                ImageSource.camera,
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: _blue,
              ),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () => Navigator.pop(
                ctx,
                ImageSource.gallery,
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
    );

    if (picked != null && mounted) {
      setState(() {
        _photoByOrderId[orderId] = File(picked.path);
      });
    }
  }

  String _nextStatus(WorkOfRider order) {
    if (order.status == _S.arrivedAtShop) {
      return order.serviceType == 'dry' ? _S.waitingDry : _S.waitingWash;
    }

    return _statusSteps[order.status]?.nextStatus ?? _S.completed;
  }

  Future<void> _confirmStep(WorkOfRider order) async {
    final step = _statusSteps[order.status];
    final needsPhoto = step?.needsPhoto ?? false;
    final photo = _photoByOrderId[order.id];

    if (needsPhoto && photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกหรือถ่ายรูปก่อนกด'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _uploadingByOrderId[order.id] = true;
    });

    try {
      final nextStatus = _nextStatus(order);

      final successMessage =
          step?.successMessage ?? 'ส่งผ้าถึงลูกค้าเรียบร้อยแล้ว';

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(
          '${widget.apiUrl}/order/rider/update/status/${order.id}',
        ),
      )
        ..fields['status'] = nextStatus
        ..fields['rider_id'] = widget.riderId;

      if (needsPhoto && photo != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            photo.path,
          ),
        );
      }

      final res = await http.Response.fromStream(
        await request.send(),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (res.statusCode == 200 && body['ok'] == true) {
        await Get.dialog<void>(
          _successDialog(successMessage),
        );

        if (!mounted) return;

        setState(() {
          _photoByOrderId.remove(order.id);
        });

        _fetchOrders();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              body['message'] as String? ?? 'เกิดข้อผิดพลาด',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      log('confirmStep: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถเชื่อมต่อได้ กรุณาลองใหม่',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingByOrderId.remove(order.id);
        });
      }
    }
  }

  Future<void> _cancelOrder(WorkOfRider order) async {
    final confirm = await Get.dialog<bool>(_confirmCancelDialog());

    if (confirm != true) return;

    setState(() => _uploadingByOrderId[order.id] = true);

    try {
      final res = await http.put(
        Uri.parse('${widget.apiUrl}/order/rider/cancel/${order.id}'),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final ok = res.statusCode == 200 && body['ok'] == true;

      _showSnack(
        body['message'] as String? ??
            (ok ? 'ยกเลิกสำเร็จ' : 'เกิดข้อผิดพลาด'),
        success: ok,
      );

      if (ok && mounted) {
        setState(() => _photoByOrderId.remove(order.id));
        _fetchOrders();
      }
    } catch (e) {
      log('cancelOrder: $e');
      _showSnack('ไม่สามารถเชื่อมต่อได้ กรุณาลองใหม่', success: false);
    } finally {
      if (mounted) {
        setState(() => _uploadingByOrderId.remove(order.id));
      }
    }
  }

  Widget _confirmCancelDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cancel_outlined,
                color: Colors.red,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'ยกเลิกคำสั่งซื้อ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'ต้องการยกเลิกออเดอร์นี้ใช่หรือไม่?\n'
              'เนื่องจากไม่พบตะกร้าของลูกค้า',
              style: TextStyle(
                fontSize: 13,
                color: _textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Get.back(result: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _textSecondary,
                      side: const BorderSide(color: _border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'ไม่ใช่',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Get.back(result: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'ยืนยัน',
                      style: TextStyle(fontWeight: FontWeight.w600),
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

  void _showSnack(String message, {bool success = true}) {
    final color = success ? _green : Colors.red;

    Get.snackbar(
      success ? 'สำเร็จ' : 'เกิดข้อผิดพลาด',
      message,
      snackPosition: SnackPosition.TOP,
      backgroundColor: Colors.white,
      colorText: _textPrimary,
      borderColor: color.withOpacity(0.4),
      borderWidth: 1,
      borderRadius: 12,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
      icon: Icon(
        success ? Icons.check_circle : Icons.error,
        color: color,
      ),
      shouldIconPulse: false,
      boxShadows: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  Widget _photoBox(
    String orderId,
    File? photo,
    bool uploading, {
    VoidCallback? onCancel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'แนบรูปภาพ',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: _textPrimary,
              ),
            ),
            const Spacer(),
            if (onCancel != null)
              TextButton.icon(
                onPressed: uploading ? null : onCancel,
                icon: const Icon(Icons.close, size: 16),
                label: const Text('ยกเลิก'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withOpacity(0.08),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: uploading ? null : () => _pickPhoto(orderId),
          child: photo != null
              ? _photoPreview(orderId, photo)
              : _photoPlaceholder(),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _photoPreview(
    String orderId,
    File photo,
  ) {
    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints(
            maxHeight: 350,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              photo,
              width: double.infinity,
              fit: BoxFit.fitWidth,
            ),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _photoByOrderId.remove(orderId);
              });
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => _pickPhoto(orderId),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 14,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'เปลี่ยนรูป',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(10),
        color: _surface,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.camera_alt_outlined,
            size: 32,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 6),
          Text(
            'แตะเพื่อเพิ่มรูป',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(WorkOfRider order) {
    final step = _statusSteps[order.status];
    final uploading = _uploadingByOrderId[order.id] ?? false;

    final shortId = order.id
        .substring(
          0,
          order.id.length.clamp(0, 8),
        )
        .toUpperCase();

    final statusLabel = step?.label ?? order.status;

    final hasActionStep = step != null;
    final needsPhoto = step?.needsPhoto ?? false;

    return _cardShell(
      leftColor: _blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$shortId',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              _chip(statusLabel, _blue),
            ],
          ),
          const SizedBox(height: 12),
          _customerRow(
            order.customer?.name,
            order.customer?.phone,
            order.customer?.profileImage,
          ),
          if (order.address != null) _addressRow(order.address!),
          if (order.orderDatetime != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.access_time,
                  size: 14,
                  color: _textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  _formatOrderDateTime(order.orderDatetime),
                  style: const TextStyle(
                    fontSize: 12,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Divider(
            height: 1,
            color: _border,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _chip(
                _serviceLabel(order.serviceType),
                _blue,
                small: true,
                isService: true,
              ),
            ],
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.note_alt_outlined,
                  size: 15,
                  color: _textSecondary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.note!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          _progressBar(order.status),
          if (hasActionStep) ...[
            const SizedBox(height: 16),
            if (needsPhoto)
              _photoBox(
                order.id,
                _photoByOrderId[order.id],
                uploading,
                onCancel: order.status == _S.pickedUp
                    ? () => _cancelOrder(order)
                    : null,
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploading ? null : () => _confirmStep(order),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: uploading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        step.buttonLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _blue,
        ),
      );
    }

    if (_error != null || _orders.isEmpty) {
      return _emptyState(
        Icons.assignment_outlined,
        _error ?? 'ไม่มีงานที่กำลังดำเนินการ',
        action: TextButton.icon(
          onPressed: _fetchOrders,
          icon: const Icon(
            Icons.refresh,
            size: 18,
            color: _blue,
          ),
          label: const Text(
            'โหลดใหม่',
            style: TextStyle(color: _blue),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _blue,
      onRefresh: _fetchOrders,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _buildOrderCard(_orders[i]),
      ),
    );
  }
}