import 'dart:async';
import 'dart:developer';
import 'dart:math' hide log;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/rider/req_accept_rider.dart';
import 'package:wash_and_dry/screens/rider/rider_order_detail_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarrider.dart';

class _OrderItem {
  final String orderId;
  final Map<String, dynamic> data;
  final String customerName;
  final String customerPhone;
  final String addressText;
  final double? addressLat;
  final double? addressLng;
  final double? distanceKm;

  const _OrderItem({
    required this.orderId,
    required this.data,
    required this.customerName,
    required this.customerPhone,
    required this.addressText,
    this.addressLat,
    this.addressLng,
    this.distanceKm,
  });

  _OrderItem withDistance(double? km) => _OrderItem(
        orderId: orderId,
        data: data,
        customerName: customerName,
        customerPhone: customerPhone,
        addressText: addressText,
        addressLat: addressLat,
        addressLng: addressLng,
        distanceKm: km,
      );
}

class RiderHomeScreen extends StatefulWidget {
  const RiderHomeScreen({super.key});

  @override
  State<RiderHomeScreen> createState() => _RiderHomeScreenState();
}

class _RiderHomeScreenState extends State<RiderHomeScreen> {
  static const _activeStatus = 'ONLINE';

  static const _statusLabels = {
    'waiting_pickup': 'รอรับผ้า',
    'waiting_delivery': 'รอส่งผ้า',
  };

  String _url = '';
  String? _riderId;
  String _riderName = '';
  String? _profileImage;
  String? _shopId;

  double? _lat;
  double? _lng;

  bool _ready = false;

  String? _riderStatus;
  StreamSubscription<DocumentSnapshot>? _riderStatusSub;

  List<_OrderItem> _cachedOrders = [];
  bool _enriching = false;
  List<String> _lastDocIds = [];
  double? _lastEnrichedLat;
  double? _lastEnrichedLng;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _riderStatusSub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _url = config['apiEndpoint']?.toString() ?? '';
    } catch (_) {}

    final shopId = await _loadSession();
    if (!mounted) return;
    setState(() {
      _shopId = shopId;
      _ready = true;
    });

    if (_riderId != null) _listenRiderStatus(_riderId!);
    _initLocation();
  }

  void _listenRiderStatus(String riderId) {
    _riderStatusSub = FirebaseFirestore.instance
        .collection('riders')
        .doc(riderId)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final status = snap.data()?['status']?.toString();
      setState(() => _riderStatus = status ?? _activeStatus);
    }, onError: (e) {
      log('listenRiderStatus error: $e');
    });
  }

  Future<void> _initLocation() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return;

      final last = await Geolocator.getLastKnownPosition();
      if (last != null && mounted) {
        setState(() {
          _lat = last.latitude;
          _lng = last.longitude;
        });
        if (_cachedOrders.isNotEmpty) _recomputeDistances();
      }

      final current = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (!mounted) return;
      setState(() {
        _lat = current.latitude;
        _lng = current.longitude;
      });
      _recomputeDistances();
    } catch (e) {
      log('initLocation error: $e');
    }
  }

  Future<String?> _loadSession() async {
    final session = Session();
    final riderId = await session.getRiderId();
    final name = await session.getFullname();
    final image = await session.getProfileImage();

    if (mounted) {
      setState(() {
        _riderId = riderId;
        _riderName = name ?? 'Rider';
        _profileImage = image;
      });
    }

    final storeId = await session.getStoreId();
    if (storeId != null && storeId.trim().isNotEmpty) return storeId.trim();
    if (riderId == null || riderId.isEmpty) return null;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('riders').doc(riderId).get();
      final ref = doc.data()?['store_id'];
      if (ref is DocumentReference) return ref.id;
    } catch (e) {
      log('loadSession error: $e');
    }
    return null;
  }

  Future<void> _maybeEnrichOrders(List<QueryDocumentSnapshot> docs) async {
    final newIds = docs.map((d) => d.id).toList();
    final sameLocation = _lastEnrichedLat == _lat && _lastEnrichedLng == _lng;
    final sameDocs = _listEquals(_lastDocIds, newIds) && _cachedOrders.isNotEmpty;

    if ((sameLocation && sameDocs) || _enriching) return;

    _enriching = true;
    _lastDocIds = newIds;
    _lastEnrichedLat = _lat;
    _lastEnrichedLng = _lng;

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
    final customerRefs = <DocumentReference>[];
    final addressRefs = <DocumentReference>[];

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final customerRef = d['customer_id'];
      final addressRef = d['address_id'];
      if (customerRef is DocumentReference) customerRefs.add(customerRef);
      if (addressRef is DocumentReference) addressRefs.add(addressRef);
    }

    final results = await Future.wait([
      _batchGet(customerRefs),
      _batchGet(addressRefs),
    ]);

    final customerSnaps = results[0];
    final addressSnaps = results[1];

    final items = docs.map((doc) {
      final d = doc.data() as Map<String, dynamic>;

      String name = 'ไม่ระบุชื่อ', phone = '', addressText = 'ไม่ระบุที่อยู่';
      double? lat, lng;

      try {
        final customerRef = d['customer_id'];
        if (customerRef is DocumentReference) {
          final cs = customerSnaps[customerRef.path];
          if (cs != null && cs.exists) {
            final cd = cs.data() as Map<String, dynamic>?;
            name = cd?['fullname']?.toString() ?? 'ไม่ระบุชื่อ';
            phone = cd?['phone']?.toString() ?? '';
          }
        }

        final addressRef = d['address_id'];
        if (addressRef is DocumentReference) {
          final as_ = addressSnaps[addressRef.path];
          if (as_ != null && as_.exists) {
            final ad = as_.data() as Map<String, dynamic>?;
            addressText = ad?['address_text']?.toString() ?? 'ไม่ระบุที่อยู่';

            final geo = ad?['location'];
            if (geo is GeoPoint) {
              lat = geo.latitude;
              lng = geo.longitude;
            } else {
              final rawLat = ad?['latitude'];
              final rawLng = ad?['longitude'];
              if (rawLat != null && rawLng != null) {
                lat = (rawLat as num).toDouble();
                lng = (rawLng as num).toDouble();
              }
            }
          }
        }
      } catch (e) {
        log('enrichOrders error for ${doc.id}: $e');
      }

      return _OrderItem(
        orderId: doc.id,
        data: d,
        customerName: name,
        customerPhone: phone,
        addressText: addressText,
        addressLat: lat,
        addressLng: lng,
        distanceKm: _calcDistance(_lat, _lng, lat, lng),
      );
    }).toList();

    items.sort((a, b) {
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    return items;
  }

  Future<Map<String, DocumentSnapshot>> _batchGet(
    List<DocumentReference> refs,
  ) async {
    if (refs.isEmpty) return {};

    final snaps = await Future.wait(refs.map((r) => r.get()));
    return {for (final s in snaps) s.reference.path: s};
  }

  void _recomputeDistances() {
    final updated = _cachedOrders.map((item) {
      return item.withDistance(
        _calcDistance(_lat, _lng, item.addressLat, item.addressLng),
      );
    }).toList();

    updated.sort((a, b) {
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });

    setState(() => _cachedOrders = updated);
  }

  Future<void> _acceptOrder(String orderId) async {
    try {
      final res = await http.put(
        Uri.parse('$_url/order/rider/accept/$orderId'),
        headers: {'Content-Type': 'application/json'},
        body: acceptOrderRequestToJson(AcceptOrderRequest(riderId: _riderId!)),
      );
      final response = acceptOrderResponseFromJson(res.body);
      _showSnack(
        response.message,
        response.ok ? const Color(0xFF34C759) : Colors.orange,
      );
    } catch (e) {
      _showSnack('เกิดข้อผิดพลาด', Colors.red);
    }
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
    const r = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) * cos(_toRad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    return r * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _toRad(double deg) => deg * pi / 180;

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBarRider(
        riderName: _riderName,
        riderId: _riderId ?? '',
        profileImage: _profileImage,
      ),
      body: !_ready || _riderId == null || (_shopId?.isEmpty ?? true)
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_riderStatus == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_riderStatus != _activeStatus) {
      return _buildInactiveState();
    }

    final storeRef = FirebaseFirestore.instance.collection('stores').doc(_shopId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('งานที่รอรับ'),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('orders')
                .where('store_id', isEqualTo: storeRef)
                .where('status', whereIn: ['waiting_pickup', 'waiting_delivery'])
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

              if (_cachedOrders.isEmpty && docs.isEmpty) {
                return _buildEmptyState();
              }

              if (_cachedOrders.isEmpty && docs.isNotEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _cachedOrders.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _OrderCard(
                  item: _cachedOrders[index],
                  statusLabels: _statusLabels,
                  onAccept: () => _acceptOrder(_cachedOrders[index].orderId),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
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
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'ไม่มีงานในขณะนี้',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pause_circle_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(
            'คุณปิดรับงานอยู่',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'เปลี่ยนสถานะเป็น "ใช้งาน" เพื่อเริ่มรับงาน',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final _OrderItem item;
  final Map<String, String> statusLabels;
  final VoidCallback onAccept;

  const _OrderCard({
    required this.item,
    required this.statusLabels,
    required this.onAccept,
  });

  static const _serviceLabels = {
    'wash': 'ซักผ้าอย่างเดียว',
    'dry': 'อบผ้าอย่างเดียว',
    'wash_dry': 'ซัก + อบ',
  };

  String get _statusLabel =>
      statusLabels[item.data['status']?.toString() ?? ''] ?? '';
  String get _serviceLabel =>
      _serviceLabels[item.data['service_type']?.toString() ?? ''] ?? '';
  String get _distanceText => item.distanceKm != null
      ? '${item.distanceKm!.toStringAsFixed(1)} กม.'
      : 'กำลังหาตำแหน่ง...';

  @override
  Widget build(BuildContext context) {
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
                    _buildHeader(),
                    const Divider(height: 1),
                    _buildBody(),
                    _buildActions(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '#${item.orderId.substring(0, 8).toUpperCase()}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
          _StatusBadge(label: _statusLabel),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final note = item.data['note']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.customerName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 6),
          _IconRow(icon: Icons.location_on_outlined, text: item.addressText),
          if (item.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 4),
            _IconRow(icon: Icons.phone_outlined, text: item.customerPhone),
             _IconRow(
    icon: Icons.access_time,
    text: _orderDateTimeText,
  ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Chip(
                  label: 'บริการ:',
                  value: _serviceLabel,
                  bg: Colors.grey.shade100,
                  textColor: Colors.black87,
                  icon: Icons.local_laundry_service,
                ),
              ),
              const SizedBox(width: 8),
              _Chip(
                label: 'ระยะห่าง:',
                value: _distanceText,
                bg: const Color(0xFFEAF5FF),
                textColor: const Color(0xFF0593FF),
              ),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _NoteRow(note: note),
          ],
        ],
      ),
    );
  }
String get _orderDateTimeText {
  final timestamp = item.data['order_datetime'];

  if (timestamp is! Timestamp) return '';

  final dateTime = timestamp.toDate();

  return '${dateTime.day}/${dateTime.month}/${dateTime.year + 543} '
      '${dateTime.hour.toString().padLeft(2, '0')}:'
      '${dateTime.minute.toString().padLeft(2, '0')} น.';
}
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                Get.to(() => RiderOrderDetailScreen(orderId: item.orderId));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0593FF),
                side: const BorderSide(color: Color(0xFF0593FF)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'รายละเอียด',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check, size: 18),
              label: const Text(
                'รับงาน',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  const _StatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF0593FF),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: Colors.grey.shade500),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final Color bg;
  final Color textColor;
  final IconData? icon;

  const _Chip({
    required this.label,
    required this.value,
    required this.bg,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 25, color: Colors.blue.shade500),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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

class _NoteRow extends StatelessWidget {
  final String note;
  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หมายเหตุ: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            note,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ],
    );
  }
}