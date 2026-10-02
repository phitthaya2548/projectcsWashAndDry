import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarrider.dart';

enum _DestType { customer, store }

class _Destination {
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String? image;
  final String? phone;
  final String? note;
  final _DestType type;

  String? distance;
  String? duration;

  _Destination({
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
    this.image,
    this.phone,
    this.note,
  });

  bool get isStore => type == _DestType.store;

  LatLng get position => LatLng(lat, lng);
}

class RiderMapScreen extends StatefulWidget {
  const RiderMapScreen({super.key});

  @override
  State<RiderMapScreen> createState() => _RiderMapScreenState();
}

class _RiderMapScreenState extends State<RiderMapScreen> {
  static const _blue = Color(0xFF0593FF);
  static const _text = Color(0xFF111827);
  static const _subText = Color(0xFF667085);
  static const _border = Color(0xFFE7ECF2);

  static const _activeStatuses = [
    'pickup_in_progress',
    'pickup_completed',
    'delivery_heading_to_shop',
    'delivery_pickup_completed',
    'delivery_in_progress',
    'store_pickup_in_progress',
  ];

  static const _minPositionWriteInterval = Duration(seconds: 4);

  String _riderName = '';
  String? _riderImage;
  String? _riderId;
  String? _apiUrl;

  GoogleMapController? _map;
  LatLng? _myPos;
  Position? _gpsPosition;
  LatLng? _lastRouteOrigin;

  final _markers = <Marker>{};
  final _polylines = <Polyline>{};

  final _jobs = <String, _Destination>{};
  final _pickupJobs = <String, _Destination>{};
  final _deliveryJobs = <String, _Destination>{};

  final _routeCache = <String, List<LatLng>>{};
  final _storeCache = <String, Map<String, dynamic>>{};

  final _jobMarkerIcons = <String, BitmapDescriptor>{};
  final _jobIconsLoading = <String>{};

  StreamSubscription<DocumentSnapshot>? _positionSub;
  StreamSubscription<QuerySnapshot>? _pickupSub;
  StreamSubscription<QuerySnapshot>? _deliverySub;
  StreamSubscription<Position>? _gpsSub;
  StreamSubscription<CompassEvent>? _compassSub;

  BitmapDescriptor? _riderMarker;
  String? _selectedJobId;
  String? _locationError;
  String? _gpsWarning;

  bool _loadingLocation = true;
  bool _navigationMode = false;
  bool _centeredOnce = false;
  bool _cameraAnimating = false;
  bool _programmaticMove = false;

  double _bearing = 0;
  double? _phoneHeading;
  double? _gpsHeading;
  DateTime? _lastNavCameraUpdate;
  DateTime? _lastPositionWrite;

  int _pickupVersion = 0;
  int _deliveryVersion = 0;
  int? _lastRouteIndex;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _pickupSub?.cancel();
    _deliverySub?.cancel();
    _gpsSub?.cancel();
    _compassSub?.cancel();
    _map?.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final session = Session();
    final config = await Configuration.getConfig();

    _apiUrl = config['apiEndpoint']?.toString() ?? '';

    final riderId = await session.getRiderId();

    if (!mounted) return;

    _riderName = await session.getFullname() ?? 'Rider';
    _riderImage = await session.getProfileImage();
    _riderId = riderId;

    if (riderId == null) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'ไม่พบข้อมูลไรเดอร์';
      });
      return;
    }

    _riderMarker = await _makeMarker(_riderImage);

    if (!mounted) return;
    setState(() {});

    _listenOrders(riderId);
    _listenPosition(riderId);
    _startGps(riderId);
    _startCompass();
  }

  void _listenPosition(String riderId) {
    _positionSub?.cancel();
    _positionSub = FirebaseFirestore.instance
        .collection('riders')
        .doc(riderId)
        .snapshots()
        .listen(
      _onPosition,
      onError: (_) {
        if (!mounted) return;
        setState(() {
          _loadingLocation = false;
          _locationError = 'ไม่สามารถโหลดตำแหน่งได้';
        });
      },
    );
  }

  void _onPosition(DocumentSnapshot snap) {
    if (!mounted) return;

    final data = snap.data() as Map<String, dynamic>?;
    final lat = (data?['latitude'] as num?)?.toDouble();
    final lng = (data?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      setState(() {
        _loadingLocation = false;
        _locationError = 'ยังไม่มีตำแหน่งของไรเดอร์ในระบบ';
      });
      return;
    }

    final pos = LatLng(lat, lng);

    setState(() {
      _myPos = pos;
      _loadingLocation = false;
      _locationError = null;
      _setRiderMarker(pos);
    });

    if (!_centeredOnce) {
      _centeredOnce = true;
      _programmaticMove = true;
      _map?.animateCamera(CameraUpdate.newLatLngZoom(pos, 14));
    }

    if (!_navigationMode) {
      _rebuildMap();
    }
  }

  void _setRiderMarker(LatLng pos) {
    _markers
      ..removeWhere((m) => m.markerId.value == 'rider')
      ..add(
        Marker(
          markerId: const MarkerId('rider'),
          position: pos,
          anchor: const Offset(0.5, 0.5),
          icon: _riderMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
  }

  /// ตั้งค่า GPS ให้ทำงานต่อได้ตอนสลับไปแอปนำทางอื่น
  LocationSettings _gpsSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'กำลังแชร์ตำแหน่งไรเดอร์',
          notificationText: 'แอปกำลังอัปเดตตำแหน่งของคุณให้ลูกค้า',
          enableWakeLock: true,
        ),
      );
    }

    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
    );
  }

  Future<void> _startGps(String riderId) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => _gpsWarning = 'กรุณาเปิด GPS');
      return;
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) setState(() => _gpsWarning = 'ไม่ได้รับอนุญาตให้ใช้ตำแหน่ง');
      return;
    }

    if (mounted) setState(() => _gpsWarning = null);

    _gpsSub?.cancel();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: _gpsSettings(),
    ).listen(
      (pos) {
        _gpsPosition = pos;

        final current = LatLng(pos.latitude, pos.longitude);

        if (pos.heading.isFinite && pos.heading >= 0 && pos.heading <= 360) {
          _gpsHeading = pos.heading;
        }

        if (pos.speed < 1.0 && _phoneHeading != null) {
          _bearing = _smoothBearing(_bearing, _phoneHeading!, 0.20);
        }

        if (mounted) {
          setState(() {
            _myPos = current;
            _setRiderMarker(current);
          });
        }

        _writeRiderPosition(riderId, pos);
        _refreshSelectedRouteIfNeeded(current);

        if (_navigationMode) {
          _updateNavigationCamera(pos);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _gpsWarning = 'สัญญาณ GPS ขาดหาย');
      },
    );
  }

  void _writeRiderPosition(String riderId, Position pos) {
    final now = DateTime.now();

    if (_lastPositionWrite != null &&
        now.difference(_lastPositionWrite!) < _minPositionWriteInterval) {
      return;
    }

    _lastPositionWrite = now;

    FirebaseFirestore.instance.collection('riders').doc(riderId).update({
      'latitude': pos.latitude,
      'longitude': pos.longitude,
    });
  }

  void _startCompass() {
    _compassSub?.cancel();

    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.headingForCameraMode ?? event.heading;

      if (heading == null || !heading.isFinite) return;

      _phoneHeading = heading;

      final gps = _gpsPosition;
      final usePhoneHeading = gps == null || gps.speed < 1.0;

      if (!usePhoneHeading) return;

      _bearing = _smoothBearing(_bearing, heading, 0.20);

      if (!_navigationMode) return;

      if (gps != null) {
        _updateNavigationCamera(gps);
        return;
      }

      final me = _myPos;
      if (me == null) return;

      _bearing = _smoothBearing(_bearing, _navBearing(me), 0.20);

      _animateNavCamera(
        CameraPosition(target: me, zoom: 18.0, tilt: 0, bearing: _bearing),
      );
    });
  }

  void _listenOrders(String riderId) {
    final riderRef =
        FirebaseFirestore.instance.collection('riders').doc(riderId);

    _pickupSub = FirebaseFirestore.instance
        .collection('orders')
        .where('rider_pickup_id', isEqualTo: riderRef)
        .where('status', whereIn: _activeStatuses)
        .snapshots()
        .listen(
          (snap) => _loadJobs(snap, pickup: true, version: ++_pickupVersion),
        );

    _deliverySub = FirebaseFirestore.instance
        .collection('orders')
        .where('rider_delivery_id', isEqualTo: riderRef)
        .where('status', whereIn: _activeStatuses)
        .snapshots()
        .listen(
          (snap) =>
              _loadJobs(snap, pickup: false, version: ++_deliveryVersion),
        );
  }

  Future<void> _loadJobs(
    QuerySnapshot snap, {
    required bool pickup,
    required int version,
  }) async {
    final result = <String, _Destination>{};

    for (final doc in snap.docs) {
      try {
        final order = doc.data() as Map<String, dynamic>;

        final customerDest = await _buildCustomerDest(order);
        if (customerDest != null) {
          result[doc.id] = customerDest;
        }

        final storeId = _refId(order['store_id']);
        if (storeId != null && !result.containsKey('store_$storeId')) {
          final storeDest = await _buildStoreDest(storeId);
          if (storeDest != null) {
            result['store_$storeId'] = storeDest;
          }
        }
      } catch (_) {}
    }

    final latest = pickup ? _pickupVersion : _deliveryVersion;
    if (version != latest || !mounted) return;

    if (pickup) {
      _pickupJobs
        ..clear()
        ..addAll(result);
    } else {
      _deliveryJobs
        ..clear()
        ..addAll(result);
    }

    _jobs
      ..clear()
      ..addAll(_pickupJobs)
      ..addAll(_deliveryJobs);

    _routeCache.removeWhere((id, _) => !_jobs.containsKey(id));
    _jobMarkerIcons.removeWhere((id, _) => !_jobs.containsKey(id));

    if (_selectedJobId == null || !_jobs.containsKey(_selectedJobId)) {
      _selectedJobId = _jobs.isEmpty ? null : _jobs.keys.first;
      _navigationMode = false;
      _lastRouteOrigin = null;
      _gpsHeading = null;
      _lastRouteIndex = null;
    }

    setState(() {});
    _rebuildMap();
  }

  Future<_Destination?> _buildCustomerDest(Map<String, dynamic> order) async {
    final addressRef = order['address_id'];
    if (addressRef is! DocumentReference) return null;

    final addressSnap = await addressRef.get();
    final address = addressSnap.data() as Map<String, dynamic>?;

    final lat = (address?['latitude'] as num?)?.toDouble();
    final lng = (address?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return null;

    final customer = await _fetchCustomer(order['customer_id']);

    return _Destination(
      name: customer.$1,
      address: address?['address_text']?.toString() ?? 'ปลายทาง',
      lat: lat,
      lng: lng,
      image: customer.$2,
      phone: customer.$3,
      note: order['note']?.toString(),
      type: _DestType.customer,
    );
  }

  Future<_Destination?> _buildStoreDest(String storeId) async {
    final store = await _fetchStore(storeId);
    if (store == null) return null;

    final lat = (store['latitude'] as num?)?.toDouble();
    final lng = (store['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) return null;

    final name = store['store_name']?.toString() ?? 'ร้านค้า';
    final address = store['address']?.toString();

    return _Destination(
      name: name,
      address: address?.isNotEmpty == true ? address! : name,
      lat: lat,
      lng: lng,
      image: store['image']?.toString(),
      type: _DestType.store,
    );
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

  Future<(String, String?, String?)> _fetchCustomer(dynamic value) async {
    DocumentReference? ref;

    if (value is DocumentReference) {
      ref = value;
    } else if (value is String && value.isNotEmpty) {
      ref = FirebaseFirestore.instance.collection('customers').doc(value);
    }

    if (ref == null) return ('ลูกค้า', null, null);

    try {
      final snap = await ref.get();
      final data = snap.data() as Map<String, dynamic>?;

      return (
        (data?['fullname'] ?? data?['username'] ?? 'ลูกค้า').toString(),
        data?['profile_image']?.toString(),
        data?['phone']?.toString(),
      );
    } catch (_) {
      return ('ลูกค้า', null, null);
    }
  }

  void _rebuildMap() {
    if (_myPos == null) return;

    _markers.removeWhere((m) =>
        m.markerId.value != 'rider' &&
        !_jobs.keys.any((id) => 'job_$id' == m.markerId.value));

    _polylines.clear();

    for (final entry in _jobs.entries) {
      final id = entry.key;
      final job = entry.value;

      _addJobMarker(id, job);

      if (id == _selectedJobId) {
        _drawCachedRoute(id);
      }

      _loadRoute(id, job);
    }
  }

  Future<void> _addJobMarker(String id, _Destination job) async {
    final cachedIcon = _jobMarkerIcons[id];

    if (cachedIcon != null) {
      _upsertJobMarker(id, job, cachedIcon);
      return;
    }

    if (_jobIconsLoading.contains(id)) return;
    _jobIconsLoading.add(id);

    try {
      final icon = await _makeMarker(job.image, isStore: job.isStore);
      _jobMarkerIcons[id] = icon;

      if (!mounted || !_jobs.containsKey(id)) return;

      _upsertJobMarker(id, job, icon);
    } finally {
      _jobIconsLoading.remove(id);
    }
  }

  void _upsertJobMarker(String id, _Destination job, BitmapDescriptor icon) {
    setState(() {
      _markers
        ..removeWhere((m) => m.markerId.value == 'job_$id')
        ..add(
          Marker(
            markerId: MarkerId('job_$id'),
            position: job.position,
            icon: icon,
            onTap: () => _selectJob(id),
            infoWindow: InfoWindow(
              title: job.isStore ? 'ร้าน ${job.name}' : job.name,
              snippet: job.address,
            ),
          ),
        );
    });
  }

  void _selectJob(String id) {
    if (!_jobs.containsKey(id)) return;

    setState(() {
      _selectedJobId = id;
      _navigationMode = false;
      _lastRouteOrigin = null;
      _lastRouteIndex = null;
      _polylines.clear();
      _drawCachedRoute(id);
    });

    final job = _jobs[id]!;

    if (_routeCache[id] == null) {
      _loadRoute(id, job);
    }

    _focusJob();
  }

  void _drawCachedRoute(String id) {
    if (id != _selectedJobId) return;

    final points = _routeCache[id];
    if (points == null) return;

    _polylines
      ..clear()
      ..add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: _blue,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
  }

  Future<void> _loadRoute(String id, _Destination job) async {
    final me = _myPos;
    if (me == null) return;

    final uri = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${me.longitude},${me.latitude};${job.lng},${job.lat}'
      '?overview=full&geometries=geojson',
    );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final route = (jsonDecode(res.body)['routes'] as List?)?.first;
      if (route == null || !mounted || !_jobs.containsKey(id)) return;

      final distance = (route['distance'] as num).toDouble();
      final duration = (route['duration'] as num).toDouble();

      final points = (route['geometry']['coordinates'] as List)
          .map(
            (p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()),
          )
          .toList();

      _routeCache[id] = points;

      if (id == _selectedJobId) {
        _lastRouteIndex = null;
      }

      setState(() {
        final current = _jobs[id];
        if (current == null) return;

        current.distance = distance >= 1000
            ? '${(distance / 1000).toStringAsFixed(1)} กม.'
            : '${distance.toInt()} ม.';
        current.duration = '${(duration / 60).ceil()} นาที';

        if (_selectedJobId == id) {
          _drawCachedRoute(id);
        }
      });
    } catch (_) {}
  }

  void _focusJob() {
    final me = _myPos;
    final id = _selectedJobId;

    if (me == null || id == null) return;

    final job = _jobs[id];
    if (job == null) return;

    final dest = job.position;

    _programmaticMove = true;

    _map?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(
            min(me.latitude, dest.latitude),
            min(me.longitude, dest.longitude),
          ),
          northeast: LatLng(
            max(me.latitude, dest.latitude),
            max(me.longitude, dest.longitude),
          ),
        ),
        72,
      ),
    );
  }

  void _toggleNavigation() {
    if (_myPos == null || _selectedJobId == null) return;

    setState(() => _navigationMode = !_navigationMode);

    if (!_navigationMode) {
      _focusJob();
      return;
    }

    _lastRouteIndex = null;
    _lastNavCameraUpdate = null;

    final rider = _gpsPosition != null
        ? LatLng(_gpsPosition!.latitude, _gpsPosition!.longitude)
        : _myPos!;

    _bearing = _navBearing(rider);

    final pos = _gpsPosition;

    if (pos != null) {
      _updateNavigationCamera(pos, force: true);
      return;
    }

    _animateNavCamera(
      CameraPosition(target: rider, zoom: 18.0, tilt: 0, bearing: _bearing),
    );
  }



  Future<void> _openGoogleMaps(_Destination job) async {
    final lat = job.lat;
    final lng = job.lng;

    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lng&travelmode=driving',
    );

    // หยุดโหมดนำทางในแอปก่อนสลับไป Google Maps
    if (_navigationMode && mounted) setState(() => _navigationMode = false);


    if (Platform.isIOS) {
      try {
        final appUri = Uri.parse(
          'comgooglemaps://?daddr=$lat,$lng&directionsmode=driving',
        );
        if (await launchUrl(appUri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }


    try {
      final ok = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      if (!ok) _showNavError();
    } catch (_) {
      _showNavError();
    }
  }

  void _showNavError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ไม่สามารถเปิด Google Maps ได้')),
    );
  }

  Widget _googleMapsLogo({double size = 26}) {
    return Image.asset(
      'assets/images/googlemap.png',
      width: size,
      height: size,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.map_rounded, size: size, color: _blue),
    );
  }


  void _updateNavigationCamera(Position pos, {bool force = false}) {
    if (!_navigationMode || _map == null) return;

    final now = DateTime.now();
    if (!force &&
        _lastNavCameraUpdate != null &&
        now.difference(_lastNavCameraUpdate!).inMilliseconds < 450) {
      return;
    }

    _lastNavCameraUpdate = now;

    final speed = max(0.0, pos.speed);
    final rider = LatLng(pos.latitude, pos.longitude);

    final zoom = speed < 2
        ? 18.2
        : speed < 8
            ? 17.8
            : speed < 18
                ? 17.2
                : 16.7;

    final directionLookAhead = (35 + speed * 3).clamp(35.0, 90.0);
    final routeDirection = _routeDirection(rider, directionLookAhead);
    final targetBearing = routeDirection?.$1 ?? _navBearing(rider);
    final smoothFactor = force ? 1.0 : (routeDirection != null ? 0.35 : 0.22);

    _bearing = _smoothBearing(_bearing, targetBearing, smoothFactor);

    _animateNavCamera(
      CameraPosition(target: rider, zoom: zoom, tilt: 0, bearing: _bearing),
    );
  }

  double _navBearing(LatLng rider) {
    final route = _routeDirection(rider, 65);
    if (route != null) return route.$1;
    if (_gpsHeading != null) return _gpsHeading!;
    if (_phoneHeading != null) return _phoneHeading!;
    return _bearing;
  }

  (double, LatLng)? _routeDirection(LatLng rider, double lookAheadMeters) {
    final id = _selectedJobId;
    if (id == null) return null;

    final points = _routeCache[id];
    if (points == null || points.length < 2) return null;

    final searchStart =
        _lastRouteIndex == null ? 0 : max(0, _lastRouteIndex! - 3);
    final searchEnd = _lastRouteIndex == null
        ? points.length - 1
        : min(points.length - 1, _lastRouteIndex! + 60);

    var nearestIndex = searchStart;
    var nearestDistance = double.infinity;

    for (var i = searchStart; i <= searchEnd; i++) {
      final d = Geolocator.distanceBetween(
        rider.latitude,
        rider.longitude,
        points[i].latitude,
        points[i].longitude,
      );

      if (d < nearestDistance) {
        nearestDistance = d;
        nearestIndex = i;
      }
    }

    if (nearestDistance > 120 || nearestIndex >= points.length - 1) return null;

    if (_lastRouteIndex != null && nearestIndex < _lastRouteIndex! - 2) {
      nearestIndex = _lastRouteIndex!;
    }

    _lastRouteIndex = nearestIndex;

    var distance = 0.0;
    var targetIndex = nearestIndex + 1;
    final effectiveLookAhead = max(lookAheadMeters, 30.0);

    for (var i = nearestIndex; i < points.length - 1; i++) {
      distance += Geolocator.distanceBetween(
        points[i].latitude,
        points[i].longitude,
        points[i + 1].latitude,
        points[i + 1].longitude,
      );

      targetIndex = i + 1;

      if (distance >= effectiveLookAhead) break;
    }

    final from = points[nearestIndex];
    var to = points[targetIndex];

    final segment = Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    );

    if (segment < 8 && targetIndex < points.length - 1) {
      to = points[min(targetIndex + 3, points.length - 1)];
    }

    return (_bearingBetween(from, to), to);
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;

    final y = sin(dLng) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    return (atan2(y, x) * 180 / pi + 360) % 360;
  }

  void _animateNavCamera(CameraPosition camera) {
    final controller = _map;
    if (controller == null || _cameraAnimating) return;

    _cameraAnimating = true;
    _programmaticMove = true;

    controller
        .animateCamera(CameraUpdate.newCameraPosition(camera))
        .whenComplete(() => _cameraAnimating = false);
  }

  double _smoothBearing(double current, double target, double factor) {
    var diff = (target - current + 540) % 360 - 180;
    const maxStep = 18.0;

    if (diff > maxStep) diff = maxStep;
    if (diff < -maxStep) diff = -maxStep;

    return (current + diff * factor + 360) % 360;
  }

  void _refreshSelectedRouteIfNeeded(LatLng current) {
    final id = _selectedJobId;
    if (id == null) return;

    if (_lastRouteOrigin != null) {
      final moved = Geolocator.distanceBetween(
        _lastRouteOrigin!.latitude,
        _lastRouteOrigin!.longitude,
        current.latitude,
        current.longitude,
      );

      if (moved < 30) return;
    }

    _lastRouteOrigin = current;

    final job = _jobs[id];
    if (job == null) return;

    _routeCache.remove(id);
    _lastRouteIndex = null;
    _loadRoute(id, job);
  }

  Future<BitmapDescriptor> _makeMarker(
    String? imageUrl, {
    bool isStore = false,
  }) async {
    const size = 110.0;
    const radius = 49.0;

    final ringColor = isStore ? _blue : _blue;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(center, size / 2, Paint()..color = ringColor);

    if (imageUrl?.isNotEmpty == true) {
      try {
        final res = await http
            .get(Uri.parse(imageUrl!))
            .timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            res.bodyBytes,
            targetWidth: size.toInt(),
            targetHeight: size.toInt(),
          );

          final image = (await codec.getNextFrame()).image;

          canvas.save();
          canvas.clipPath(
            Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
          );
          canvas.drawImageRect(
            image,
            Rect.fromLTWH(
              0,
              0,
              image.width.toDouble(),
              image.height.toDouble(),
            ),
            Rect.fromCircle(center: center, radius: radius),
            Paint(),
          );
          canvas.restore();

          return _descriptor(recorder, size);
        }
      } catch (_) {}
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color =
            isStore ? const Color(0xFFFFF1E5) : const Color(0xFFEAF6FF),
    );

    final paint = Paint()..color = ringColor;

    if (isStore) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: const Offset(size / 2, size / 2 + 10),
            width: 46,
            height: 30,
          ),
          const Radius.circular(5),
        ),
        paint,
      );
      canvas.drawPath(
        Path()
          ..moveTo(size / 2 - 28, size / 2 - 6)
          ..lineTo(size / 2 + 28, size / 2 - 6)
          ..lineTo(size / 2 + 20, size / 2 - 22)
          ..lineTo(size / 2 - 20, size / 2 - 22)
          ..close(),
        paint,
      );
    } else {
      canvas.drawCircle(const Offset(size / 2, size / 2 - 10), 15, paint);
      canvas.drawArc(
        Rect.fromCenter(
          center: const Offset(size / 2, size / 2 + 24),
          width: 44,
          height: 26,
        ),
        0,
        pi,
        true,
        paint,
      );
    }

    return _descriptor(recorder, size);
  }

  Future<BitmapDescriptor> _descriptor(
    ui.PictureRecorder recorder,
    double size,
  ) async {
    final image =
        await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBarRider(
        riderName: _riderName,
        riderId: _riderId ?? '',
        profileImage: _riderImage,
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loadingLocation && _myPos == null) {
      return const Center(child: CircularProgressIndicator(color: _blue));
    }

    if (_locationError != null && _myPos == null) {
      return _errorView();
    }

    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _myPos!, zoom: 14),
          onMapCreated: (controller) {
            _map = controller;
            if (_selectedJobId != null) {
              Future.delayed(const Duration(milliseconds: 250), _focusJob);
            }
          },
          onCameraMoveStarted: () {
            if (_navigationMode && !_programmaticMove) {
              setState(() => _navigationMode = false);
            }
          },
          onCameraIdle: () => _programmaticMove = false,
          markers: _markers,
          polylines: _polylines,
          myLocationEnabled: false,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          scrollGesturesEnabled: !_navigationMode,
          zoomGesturesEnabled: !_navigationMode,
          rotateGesturesEnabled: !_navigationMode,
          tiltGesturesEnabled: !_navigationMode,
        ),
        if (_gpsWarning != null) _gpsBanner(),
        if (_jobs.isNotEmpty) _jobsButton(),
        if (_selectedJobId != null) _selectedCard(),
        _navigationButton(),
      ],
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _locationError!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _subText),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed:
                  _riderId == null ? null : () => _listenPosition(_riderId!),
              style: FilledButton.styleFrom(backgroundColor: _blue),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gpsBanner() {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _gpsWarning!,
                  style: const TextStyle(fontSize: 12, color: _text),
                ),
              ),
              TextButton(
                onPressed: _riderId == null ? null : () => _startGps(_riderId!),
                child: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jobsButton() {
    return Positioned(
      top: _gpsWarning == null ? 14 : 70,
      left: 14,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: _showJobs,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                'จุดหมายของฉัน  ${_jobs.length}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _text,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navigationButton() {
    return Positioned(
      right: 14,
      bottom: _jobs.isEmpty ? 28 : 150,
      child: InkWell(
        onTap: _toggleNavigation,
        customBorder: const CircleBorder(),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _navigationMode ? _blue : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _navigationMode ? _blue : _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            _navigationMode
                ? Icons.navigation_rounded
                : Icons.my_location_rounded,
            color: _navigationMode ? Colors.white : _blue,
            size: 21,
          ),
        ),
      ),
    );
  }

  Widget _selectedCard() {
    final id = _selectedJobId;
    final job = id == null ? null : _jobs[id];

    if (job == null) return const SizedBox.shrink();

    final accent = job.isStore ? _blue : _blue;

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
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
                  _avatar(job.image, 46, isStore: job.isStore),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                job.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _text,
                                ),
                              ),
                            ),
                            if (job.isStore) ...[
                              const SizedBox(width: 6),
                              _tag('ร้าน'),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (job.distance != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          job.distance!,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          job.duration ?? '',
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: _subText,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.7,
                        color: _blue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF0F2F5)),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextButton(
                      onPressed: _toggleNavigation,
                      child: Text(
                        _navigationMode ? 'หยุดนำทาง' : 'เริ่มนำทาง',
                        style: TextStyle(
                          color: _navigationMode ? accent : _text,
                          fontWeight: _navigationMode
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: const Color(0xFFF0F2F5),
                  ),
                  Expanded(
                    flex: 4,
                    child: TextButton(
                      onPressed: () => _openGoogleMaps(job),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _googleMapsLogo(size: 18),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Google Maps',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 22,
                    color: const Color(0xFFF0F2F5),
                  ),
                  Expanded(
                    flex: 3,
                    child: TextButton(
                      onPressed: () => _showDetail(job),
                      child: Text(
                        'รายละเอียด',
                        style: TextStyle(
                          color: accent,
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
      ),
    );
  }

  Widget _tag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _blue,
        ),
      ),
    );
  }

  void _showJobs() {
    final entries = _jobs.entries.toList()
      ..sort((a, b) {
        if (a.value.isStore == b.value.isStore) return 0;
        return a.value.isStore ? -1 : 1;
      });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD0D5DD),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'จุดหมายของฉัน',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: _text,
                      ),
                    ),
                  ),
                  Text(
                    '${entries.length} จุด',
                    style: const TextStyle(fontSize: 12, color: _subText),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final entry = entries[index];
                    final job = entry.value;
                    final selected = entry.key == _selectedJobId;
                    final accent = job.isStore ? _blue : _blue;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 2,
                      ),
                      leading: _avatar(job.image, 42, isStore: job.isStore),
                      title: Row(
                        children: [
                          Flexible(
                            child: Text(
                              job.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (job.isStore) ...[
                            const SizedBox(width: 6),
                            _tag('ร้าน'),
                          ],
                        ],
                      ),
                      subtitle: Text(
                        job.address,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: _subText,
                        ),
                      ),
                      trailing: job.distance == null
                          ? null
                          : Text(
                              job.distance!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: selected ? accent : _subText,
                              ),
                            ),
                      tileColor: selected ? accent.withOpacity(0.05) : null,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _selectJob(entry.key);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(_Destination job) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD0D5DD),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _avatar(job.image, 50, isStore: job.isStore),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: _text,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.isStore ? 'ร้านค้า' : 'ลูกค้า',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: _subText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (job.distance != null)
                    Text(
                      job.distance!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _detail('ที่อยู่', job.address),
              if (job.phone?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _detail('เบอร์โทรศัพท์', job.phone!),
              ],
              if (job.note?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _detail('หมายเหตุ', job.note!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 10.5, color: _subText),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 13, color: _text, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? imageUrl, double size, {bool isStore = false}) {
    if (imageUrl?.isNotEmpty == true) {
      return ClipOval(
        child: Image.network(
          imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _avatarFallback(size, isStore),
        ),
      );
    }

    return _avatarFallback(size, isStore);
  }

  Widget _avatarFallback(double size, bool isStore) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _blue.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isStore ? Icons.storefront_rounded : Icons.person_rounded,
        color: _blue,
        size: 22,
      ),
    );
  }
}