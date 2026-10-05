import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;
import 'package:cloud_firestore/cloud_firestore.dart';
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

String _formatTs(Timestamp ts) {
  final d = ts.toDate().toLocal();
  return '${d.day}/${d.month}/${d.year + 543} '
      '${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')} น.';
}

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
                Tab(text: 'งานที่ทำเสร็จแล้ว'),
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

class _CompletedTab extends StatelessWidget {
  final String riderId;

  const _CompletedTab({
    required this.riderId,
  });

  Future<Map<String, DocumentSnapshot>> _batchGet(
    List<DocumentReference?> refs,
  ) async {
    final validRefs = refs.whereType<DocumentReference>().toList();

    if (validRefs.isEmpty) return {};

    final snapshots = await Future.wait(
      validRefs.map((ref) => ref.get()),
    );

    return {
      for (final snap in snapshots)
        snap.reference.path: snap,
    };
  }

  @override
  Widget build(BuildContext context) {
    final riderRef = FirebaseFirestore.instance.doc(
      'riders/$riderId',
    );

    final ordersStream = FirebaseFirestore.instance
        .collection('orders')
        .where(
          Filter.or(
            Filter('rider_pickup_id', isEqualTo: riderRef),
            Filter('rider_delivery_id', isEqualTo: riderRef),
          ),
        )
        .where(
          'status',
          whereIn: [
            _S.arrivedAtShop,
            _S.waitingWash,
            _S.waitingDry,
            _S.completed,
          ],
        )
        .orderBy(
          'order_datetime',
          descending: true,
        )
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: ordersStream,
      builder: (_, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: _blue,
            ),
          );
        }

        if (snapshot.hasError) {
          return _emptyState(
            Icons.error_outline,
            'เกิดข้อผิดพลาด',
          );
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _emptyState(
            Icons.inbox_outlined,
            'ยังไม่มีงานที่ทำเสร็จแล้ว',
          );
        }

        final customerRefs = docs
            .map(
              (d) => (d.data() as Map)['customer_id']
                  as DocumentReference?,
            )
            .toList();

        final addressRefs = docs
            .map(
              (d) => (d.data() as Map)['address_id']
                  as DocumentReference?,
            )
            .toList();

        return FutureBuilder(
          future: Future.wait([
            _batchGet(customerRefs),
            _batchGet(addressRefs),
          ]),
          builder: (_, related) {
            final customers =
                related.data?[0]
                    as Map<String, DocumentSnapshot>? ??
                {};

            final addresses =
                related.data?[1]
                    as Map<String, DocumentSnapshot>? ??
                {};

            final loadingRelated =
                related.connectionState ==
                ConnectionState.waiting;

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
              itemBuilder: (_, i) => _buildOrderCard(
                docs[i],
                customers,
                addresses,
                loadingRelated,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOrderCard(
    QueryDocumentSnapshot doc,
    Map<String, DocumentSnapshot> customers,
    Map<String, DocumentSnapshot> addresses,
    bool loadingRelated,
  ) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] as String?;

    final isArrived = status == _S.arrivedAtShop;
    final isWaiting =
        status == _S.waitingWash ||
        status == _S.waitingDry;

    final color =
        isArrived || isWaiting ? _blue : _green;

    final label = isArrived
        ? 'ถึงร้านแล้ว'
        : (isWaiting ? 'รอซัก' : 'เสร็จสิ้น');

    final shortId = doc.id
        .substring(0, doc.id.length.clamp(0, 8))
        .toUpperCase();

    final customerRef =
        data['customer_id'] as DocumentReference?;

    final addressRef =
        data['address_id'] as DocumentReference?;

    final customer = customerRef != null
        ? customers[customerRef.path]?.data()
              as Map<String, dynamic>?
        : null;

    final address = addressRef != null
        ? addresses[addressRef.path]?.data()
              as Map<String, dynamic>?
        : null;

    return _cardShell(
      leftColor: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '#$shortId',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _textPrimary,
                ),
              ),
              _chip(label, color),
            ],
          ),
          const SizedBox(height: 12),
          if (loadingRelated)
            const SizedBox(
              height: 20,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _blue,
                ),
              ),
            )
          else ...[
            _customerRow(
              customer?['fullname'],
              customer?['phone'],
              customer?['profile_image'],
            ),
            if (address?['address_text'] != null)
              _addressRow(
                address!['address_text'],
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
                _serviceLabel(
                  data['service_type'] as String?,
                ),
                _textSecondary,
                small: true,
                isService: true,
              ),
              if (data['order_datetime'] != null) ...[
                const SizedBox(width: 8),
                Text(
                  _formatTs(
                    data['order_datetime'] as Timestamp,
                  ),
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

      final lastKnown =
          await Geolocator.getLastKnownPosition();

      if (lastKnown != null) {
        _lat = lastKnown.latitude;
        _lng = lastKnown.longitude;

        if (mounted) {
          _recomputeDistances();
        }
      }

      final current =
          await Geolocator.getCurrentPosition(
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
          distanceKm: km != null
              ? double.parse(km.toStringAsFixed(1))
              : null,
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

      final body =
          jsonDecode(res.body) as Map<String, dynamic>;

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
          _error =
              body['message'] as String? ??
              'ไม่พบออเดอร์';
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
    final source =
        await showModalBottomSheet<ImageSource>(
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
      return order.serviceType == 'dry'
          ? _S.waitingDry
          : _S.waitingWash;
    }

    return _statusSteps[order.status]?.nextStatus ??
        _S.completed;
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
          step?.successMessage ??
          'ส่งผ้าถึงลูกค้าเรียบร้อยแล้ว';

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

      final body =
          jsonDecode(res.body) as Map<String, dynamic>;

      if (!mounted) return;

      if (res.statusCode == 200 &&
          body['ok'] == true) {
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
              body['message'] as String? ??
                  'เกิดข้อผิดพลาด',
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

  Widget _photoBox(
    String orderId,
    File? photo,
    bool uploading,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'แนบรูปภาพ',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: uploading
              ? null
              : () => _pickPhoto(orderId),
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
    final uploading =
        _uploadingByOrderId[order.id] ?? false;

    final shortId = order.id
        .substring(
          0,
          order.id.length.clamp(0, 8),
        )
        .toUpperCase();

    final statusLabel =
        step?.label ?? order.status;

    final hasActionStep = step != null;
    final needsPhoto = step?.needsPhoto ?? false;

    return _cardShell(
      leftColor: _blue,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween,
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
          if (order.address != null)
            _addressRow(order.address!),
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
                  _formatOrderDateTime(
                    order.orderDatetime,
                  ),
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
          if (order.note != null &&
              order.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
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
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: uploading
                    ? null
                    : () => _confirmStep(order),
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
                        step!.buttonLabel,
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
        separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
        itemBuilder: (_, i) =>
            _buildOrderCard(_orders[i]),
      ),
    );
  }
}