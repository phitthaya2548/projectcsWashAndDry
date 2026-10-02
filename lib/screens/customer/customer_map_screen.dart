import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';

class CustomerMapScreen extends StatefulWidget {
  final String orderId;

  const CustomerMapScreen({super.key, required this.orderId});

  @override
  State<CustomerMapScreen> createState() => _CustomerMapScreenState();
}

class _CustomerMapScreenState extends State<CustomerMapScreen> {
  static const _blue = Color(0xFF0593FF);
  static const _orange = Color(0xFFFF8A34);

  static const _pickupStatuses = {
    'pickup_in_progress',
    'pickup_completed',
  };

  static const _deliveryStatuses = {
    'delivery_heading_to_shop',
    'delivery_pickup_completed',
    'delivery_in_progress',
  };

  // สถานะที่ให้วาดเส้นทางไปร้าน
  static const _toStoreStatuses = {
    'pickup_completed', // กำลังนำผ้าไปที่ร้าน
    'delivery_heading_to_shop', // กำลังไปที่ร้าน
  };

  GoogleMapController? _map;
  StreamSubscription<DocumentSnapshot>? _orderSub, _riderSub;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final Map<String, Map<String, dynamic>> _storeCache = {};

  String _status = '', _riderName = '', _address = '';
  String? _riderId, _riderImage, _phone, _vehicle, _plate;
  String? _distance, _duration, _customerImage, _error;
  String? _apiUrl, _storeId, _storeName, _storeAddress, _storeImage;

  LatLng? _riderPos, _destPos, _storePos;
  BitmapDescriptor? _riderIcon, _destIcon, _storeIcon;

  bool _loading = true;
  bool _fetchingStore = false;
  int _trackingVersion = 0, _routeVersion = 0;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _trackingVersion++;
    _routeVersion++;
    _orderSub?.cancel();
    _riderSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  /// ปลายทางของเส้นทางตามสถานะปัจจุบัน
  LatLng? get _routeTarget {
    if (_toStoreStatuses.contains(_status) && _storePos != null) {
      return _storePos;
    }
    return _destPos;
  }

  Future<void> _init() async {
    try {
      final config = await Configuration.getConfig();
      _apiUrl = config['apiEndpoint']?.toString() ?? '';

      final ref = FirebaseFirestore.instance.collection('orders').doc(widget.orderId);
      final snap = await ref.get();

      if (!snap.exists) {
        if (mounted) setState(() { _error = 'ไม่พบข้อมูลออเดอร์'; _loading = false; });
        return;
      }

      final data = snap.data()!;
      _status = data['status']?.toString() ?? '';

      await _loadDestination(data);
      await _loadStore(data);
      await _setupRider(data);

      _orderSub?.cancel();
      _orderSub = ref.snapshots().listen(_onOrderUpdate);
    } catch (e) {
      if (mounted) setState(() { _error = 'เกิดข้อผิดพลาด: $e'; _loading = false; });
    }
  }

  Future<void> _loadDestination(Map<String, dynamic> data) async {
    final customerRef = data['customer_id'] as DocumentReference?;
    if (customerRef != null) {
      final snap = await customerRef.get();
      final d = snap.data() as Map<String, dynamic>?;
      _customerImage = d?['profile_image']?.toString();
    }

    final addressRef = data['address_id'] as DocumentReference?;
    if (addressRef == null) return;

    final snap = await addressRef.get();
    final d = snap.data() as Map<String, dynamic>?;
    final lat = (d?['latitude'] as num?)?.toDouble();
    final lng = (d?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _destPos = LatLng(lat, lng);
    _address = d?['address_text']?.toString() ?? 'ปลายทาง';
    _destIcon = await _makeMarker(_customerImage, Colors.red);

    if (!mounted) return;

    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'dest')
        ..add(Marker(
          markerId: const MarkerId('dest'),
          position: _destPos!,
          icon: _destIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: 'ปลายทาง', snippet: _address),
        ));
    });
  }

  String? _refId(dynamic value) {
    if (value is DocumentReference) return value.id;
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  Future<Map<String, dynamic>?> _fetchStore(String storeId) async {
    final cached = _storeCache[storeId];
    if (cached != null) return cached;

    final base = _apiUrl;
    if (base == null || base.isEmpty) return null;

    try {
      final res = await http
          .get(Uri.parse('$base/order/rider/store/address/$storeId'))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return null;

      final data = body['data'] as Map<String, dynamic>?;
      if (data == null) return null;

      _storeCache[storeId] = data;
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadStore(Map<String, dynamic> data) async {
    final storeId = _refId(data['store_id']);
    if (storeId == null) return;
    _storeId = storeId;

    final store = await _fetchStore(storeId);
    if (store == null) return;

    final lat = (store['latitude'] as num?)?.toDouble();
    final lng = (store['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _storePos = LatLng(lat, lng);
    _storeName = store['store_name']?.toString() ?? 'ร้านค้า';
    _storeAddress = store['address']?.toString();
    _storeImage = store['image']?.toString();
    _storeIcon ??= await _makeMarker(_storeImage, _orange);

    if (!mounted) return;

    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'store')
        ..add(Marker(
          markerId: const MarkerId('store'),
          position: _storePos!,
          icon: _storeIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: 'ร้าน $_storeName',
            snippet: _storeAddress?.isNotEmpty == true ? _storeAddress : _storeName,
          ),
        ));
    });
  }

  DocumentReference? _activeRider(Map<String, dynamic> data) {
    if (_pickupStatuses.contains(_status)) {
      return data['rider_pickup_id'] as DocumentReference?;
    }

    if (_deliveryStatuses.contains(_status)) {
      return data['rider_delivery_id'] as DocumentReference?;
    }

    return null;
  }

  Future<void> _setupRider(Map<String, dynamic> data) async {
    final version = ++_trackingVersion;
    final ref = _activeRider(data);

    if (ref == null) {
      _clearRider();
      return;
    }

    if (_riderId == ref.id && _riderSub != null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    await _riderSub?.cancel();
    _riderSub = null;

    try {
      final snap = await ref.get();
      if (!mounted || version != _trackingVersion || !snap.exists) return;

      final d = snap.data() as Map<String, dynamic>?;
      final name = (d?['fullname'] ?? d?['username'] ?? 'ไรเดอร์').toString();
      final image = d?['profile_image']?.toString();
      final icon = await _makeMarker(image, _blue);

      if (!mounted || version != _trackingVersion) return;

      _riderId = ref.id;

      setState(() {
        _riderName = name;
        _riderImage = image;
        _phone = d?['phone']?.toString();
        _vehicle = d?['vehicle_type']?.toString();
        _plate = d?['license_plate']?.toString();
        _riderIcon = icon;
        _loading = false;
      });

      _riderSub = ref.snapshots().listen(_onRiderUpdate);
    } catch (_) {
      if (mounted && version == _trackingVersion) _clearRider();
    }
  }

  void _onOrderUpdate(DocumentSnapshot snap) {
    if (!snap.exists || !mounted) return;

    final data = snap.data() as Map<String, dynamic>;
    final newStatus = data['status']?.toString() ?? '';

    if (newStatus == _status) return;

    setState(() => _status = newStatus);

    // ตั้งค่าไรเดอร์ใหม่ แล้ววาดเส้นทางทันทีตามสถานะใหม่
    _setupRider(data).then((_) {
      if (mounted) _updateRoute();
    });
  }

  void _clearRider() {
    _trackingVersion++;
    _routeVersion++;
    _riderSub?.cancel();
    _riderSub = null;
    _riderId = null;

    if (!mounted) return;

    setState(() {
      _riderName = '';
      _riderImage = null;
      _phone = null;
      _vehicle = null;
      _plate = null;
      _riderIcon = null;
      _riderPos = null;
      _distance = null;
      _duration = null;
      _loading = false;
      _markers.removeWhere((m) => m.markerId.value == 'rider');
      _polylines.removeWhere((p) => p.polylineId.value == 'route');
    });

    if (_storePos != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_storePos!, 15));
    } else if (_destPos != null) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_destPos!, 15));
    }
  }

  void _onRiderUpdate(DocumentSnapshot snap) {
    if (!snap.exists || !mounted) return;

    final d = snap.data() as Map<String, dynamic>;
    final lat = (d['latitude'] as num?)?.toDouble();
    final lng = (d['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    final pos = LatLng(lat, lng);

    setState(() {
      _riderPos = pos;
      _loading = false;
      _markers
        ..removeWhere((m) => m.markerId.value == 'rider')
        ..add(Marker(
          markerId: const MarkerId('rider'),
          position: pos,
          icon: _riderIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: _riderName),
        ));
    });

    _updateRoute();
  }

  /// วาดเส้นทางจากไรเดอร์ไปยังปลายทางตามสถานะ (ร้าน หรือ ลูกค้า)
  Future<void> _updateRoute() async {
    // ต้องไปร้านแต่ยังไม่มีพิกัดร้าน -> ลองดึงใหม่ (กันยิงซ้ำด้วย flag)
    if (_toStoreStatuses.contains(_status) &&
        _storePos == null &&
        _storeId != null &&
        !_fetchingStore) {
      _fetchingStore = true;
      try {
        await _loadStore({'store_id': _storeId});
      } finally {
        _fetchingStore = false;
      }
    }

    final from = _riderPos;
    final to = _routeTarget;
    if (from == null || to == null || !mounted) return;

    _drawRoute(from, to);
    _fitBounds([from, to]);
  }

  Future<void> _drawRoute(LatLng from, LatLng to) async {
    final version = ++_routeVersion;

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
      '?overview=full&geometries=geojson',
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final routes = jsonDecode(res.body)['routes'] as List?;
      if (routes == null || routes.isEmpty) return;

      final route = routes.first;
      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();

      final points = (route['geometry']['coordinates'] as List)
          .map((c) => LatLng(
                (c[1] as num).toDouble(),
                (c[0] as num).toDouble(),
              ))
          .toList();

      if (!mounted || version != _routeVersion || _riderPos == null) return;

      setState(() {
        _distance = distance >= 1000
            ? '${(distance / 1000).toStringAsFixed(1)} กม.'
            : '${distance.toInt()} ม.';
        _duration = '${(duration / 60).ceil()} นาที';

        _polylines
          ..removeWhere((p) => p.polylineId.value == 'route')
          ..add(Polyline(
            polylineId: const PolylineId('route'),
            points: points,
            color: _blue,
            width: 5,
          ));
      });
    } catch (_) {}
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;

    if (points.length == 1 || points.every((p) => p == points.first)) {
      _map?.animateCamera(CameraUpdate.newLatLngZoom(points.first, 16));
      return;
    }

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;

    for (final p in points) {
      minLat = min(minLat, p.latitude);
      maxLat = max(maxLat, p.latitude);
      minLng = min(minLng, p.longitude);
      maxLng = max(maxLng, p.longitude);
    }

    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80,
      ),
    );
  }

  Future<BitmapDescriptor> _makeMarker(String? imageUrl, Color color) async {
    const radius = 54.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawCircle(
      const Offset(60, 60),
      60,
      Paint()..color = color,
    );

    if (imageUrl?.isNotEmpty == true) {
      try {
        final res = await http.get(Uri.parse(imageUrl!));
        final codec = await ui.instantiateImageCodec(
          res.bodyBytes,
          targetWidth: 120,
          targetHeight: 120,
        );
        final image = (await codec.getNextFrame()).image;

        canvas.save();
        canvas.clipPath(
          Path()..addOval(
            Rect.fromCircle(center: const Offset(60, 60), radius: radius),
          ),
        );
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromCircle(center: const Offset(60, 60), radius: radius),
          Paint(),
        );
        canvas.restore();
        return _descriptor(recorder);
      } catch (_) {}
    }

    canvas.drawCircle(
      const Offset(60, 60),
      radius,
      Paint()..color = color.withOpacity(.2),
    );

    final p = Paint()..color = color;
    canvas.drawCircle(const Offset(60, 48), 17, p);
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(60, 82), width: 48, height: 28),
      0,
      pi,
      true,
      p,
    );

    return _descriptor(recorder);
  }

  Future<BitmapDescriptor> _descriptor(ui.PictureRecorder recorder) async {
    final image = await recorder.endRecording().toImage(120, 120);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  String get _statusText {
    const data = {
      'pickup_in_progress': 'กำลังไปรับผ้า',
      'pickup_completed': 'กำลังนำผ้าไปที่ร้าน',
      'delivery_heading_to_shop': 'กำลังไปที่ร้าน',
      'delivery_pickup_completed': 'รับผ้าที่ร้านแล้ว',
      'delivery_in_progress': 'กำลังจัดส่ง',
    };
    return data[_status] ?? '';
  }

  String get _waitingText {
    const data = {
      'waiting_pickup': 'กำลังรอไรเดอร์รับผ้ารับงาน...',
      'waiting_delivery': 'กำลังรอไรเดอร์ส่งผ้ารับงาน...',
      'completed': 'จัดส่งเรียบร้อยแล้ว',
      'cancelled': 'ออเดอร์ถูกยกเลิก',
    };
    return data[_status] ?? 'ยังไม่มีไรเดอร์ที่ต้องติดตาม';
  }

  String _vehicleText(String value) {
    const data = {
      'motorcycle': 'มอเตอร์ไซค์',
      'car': 'รถยนต์',
    };

    final normalized = value.trim().toLowerCase();
    return data[normalized] ?? value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text(
          'ติดตามไรเดอร์',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Get.back(result: true),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 15),
            FilledButton(
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _init();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    final initial = _riderPos ?? _storePos ?? _destPos ?? const LatLng(13.7563, 100.5018);

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: initial, zoom: 14),
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          onMapCreated: (c) {
            _map = c;
            final target = _routeTarget;
            if (_riderPos != null && target != null) {
              _fitBounds([_riderPos!, target]);
            } else if (_storePos != null) {
              c.animateCamera(CameraUpdate.newLatLngZoom(_storePos!, 15));
            } else if (_destPos != null) {
              c.animateCamera(CameraUpdate.newLatLngZoom(_destPos!, 15));
            }
          },
        ),
        Positioned(
          left: 14,
          right: 14,
          bottom: 24,
          child: _riderPos != null ? _riderCard() : _waitingCard(),
        ),
      ],
    );
  }

  Widget _riderCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.1),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _avatar(),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _riderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: _blue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_distance != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _distance!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: _blue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _duration ?? '',
                      style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _infoBox('เบอร์โทร', _phone ?? '-')),
              const SizedBox(width: 7),
              Expanded(
                child: _infoBox(
                  'พาหนะ',
                  _vehicle?.isNotEmpty == true ? _vehicleText(_vehicle!) : '-',
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _infoBox(
                  'ทะเบียนรถ',
                  _plate?.isNotEmpty == true ? _plate!.toUpperCase() : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar() {
    return Container(
      width: 55,
      height: 55,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: _blue,
      ),
      child: ClipOval(
        child: _riderImage?.isNotEmpty == true
            ? Image.network(
                _riderImage!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFFEAF6FF),
      alignment: Alignment.center,
      child: Text(
        _riderName.isEmpty ? 'R' : _riderName.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 20,
          color: _blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoBox(String title, String value) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500),
          ),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _waitingCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 15,
          ),
        ],
      ),
      child: Text(
        _waitingText,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}