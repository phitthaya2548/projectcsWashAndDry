import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/rider/res_order_detail_rider.dart';
import 'package:wash_and_dry/service/session_service.dart';

class RiderOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const RiderOrderDetailScreen({
    super.key,
    required this.orderId,
  });

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  static const _blue = Color(0xFF0593FF);
  static const _green = Color(0xFF16A34A);
  static const _distanceFilterMeters = 10;

  static const _sendInterval = Duration(seconds: 10);

  String url = '';
  bool isLoading = true;
  String? error;

  GoogleMapController? _mapController;
  OrderDetailResponse? orderDetailResponse;
  OrderDetailData? order;

  Position? currentRiderPosition;
  StreamSubscription<Position>? _positionSub;
  DateTime? _lastSentAt;
  bool _syncing = false;
  bool _didFitBounds = false;

  double? _serverDistanceKm;
  String? _customerImageUrl;

 
  String? _riderImageUrl;
  String _riderName = 'Rider';


  BitmapDescriptor? _customerIcon;
  BitmapDescriptor? _riderIcon;
  String? _customerIconUrl;

  @override
  void initState() {
    super.initState();
    loadConfigAndFetch();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }


  Future<void> loadConfigAndFetch() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';

      if (url.isEmpty) {
        setState(() {
          error = 'ไม่พบ apiEndpoint';
          isLoading = false;
        });
        return;
      }

      _loadRiderProfile();

      final position = await _resolveInitialPosition();
      if (!mounted) return;
      currentRiderPosition = position;

      await fetchOrderDetail();

      _startPositionStream();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'โหลด config ไม่สำเร็จ: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _loadRiderProfile() async {
    try {
      final session = Session();
      _riderImageUrl = await session.getProfileImage();
      _riderName = (await session.getFullname()) ?? 'Rider';

      final icon = await _createAvatarMarker(
        imageUrl: _riderImageUrl,
        initial: _riderName.isNotEmpty ? _riderName[0].toUpperCase() : 'R',
        color: _blue,
      );

      if (!mounted) return;
      setState(() => _riderIcon = icon);
    } catch (e) {
      log('loadRiderProfile error: $e');
    }
  }

  Future<bool> _ensureLocationPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }

    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<Position?> _resolveInitialPosition() async {
    try {
      if (!await _ensureLocationPermission()) return null;

      try {
        return await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 8),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      log('resolveInitialPosition error: $e');
      return null;
    }
  }

  void _startPositionStream() {
    _positionSub?.cancel();

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterMeters,
      ),
    ).listen(
      (position) {
        if (!mounted) return;

        setState(() => currentRiderPosition = position);

  
        if (!_didFitBounds) _fitMapToBounds();

        _sendLocationThrottled();
      },
      onError: (e) => log('positionStream error: $e'),
    );
  }

  Future<void> _sendLocationThrottled() async {
    final now = DateTime.now();
    if (_lastSentAt != null && now.difference(_lastSentAt!) < _sendInterval) {
      return;
    }
    await fetchOrderDetail(silent: true);
  }

  Future<void> fetchOrderDetail({bool silent = false}) async {
    if (silent && _syncing) return;
    _syncing = true;
    _lastSentAt = DateTime.now();

    try {
      if (!silent) {
        setState(() {
          isLoading = true;
          error = null;
        });
      }

      final position = currentRiderPosition;
      final uri = Uri.parse('$url/order/rider/detail/${widget.orderId}').replace(
        queryParameters: {
          if (position != null) 'lat': position.latitude.toString(),
          if (position != null) 'lng': position.longitude.toString(),
        },
      );

      final response = await http.get(uri);
      final parsed = orderDetailResponseFromJson(response.body);

      if (response.statusCode != 200 || parsed.ok != true) {
        if (!silent && mounted) {
          setState(() {
            error = parsed.message ?? 'เกิดข้อผิดพลาด';
            isLoading = false;
          });
        }
        return;
      }


      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final customer = data?['customer'] as Map<String, dynamic>?;
      final serverDistance = (data?['distance_km'] as num?)?.toDouble();
      final customerImage = customer?['profile_image']?.toString();

      if (!mounted) return;

      setState(() {
        _serverDistanceKm = serverDistance;
        _customerImageUrl = customerImage;

        if (!silent) {
          orderDetailResponse = parsed;
          order = parsed.data;
          isLoading = false;
        }
      });

      _loadCustomerIcon();
    } catch (e) {
      log('fetchOrderDetail error: $e');
      if (!silent && mounted) {
        setState(() {
          error = 'ดึงข้อมูลไม่สำเร็จ: $e';
          isLoading = false;
        });
      }
    } finally {
      _syncing = false;
    }
  }

  Future<void> _loadCustomerIcon() async {
    // โหลดใหม่เฉพาะตอนยังไม่มีไอคอน หรือรูปเปลี่ยน
    if (_customerIcon != null && _customerIconUrl == _customerImageUrl) return;
    _customerIconUrl = _customerImageUrl;

    final name = order?.customer?.fullname ?? '';

    final icon = await _createAvatarMarker(
      imageUrl: _customerImageUrl,
      initial: name.isNotEmpty ? name[0].toUpperCase() : 'C',
      color: _green,
    );

    if (!mounted) return;
    setState(() => _customerIcon = icon);
  }

 
  Future<BitmapDescriptor> _createAvatarMarker({
    required String? imageUrl,
    required String initial,
    required Color color,
  }) async {
    const double size = 110;
    const double border = 8;

    ui.Image? image;

    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final res = await http
            .get(Uri.parse(imageUrl))
            .timeout(const Duration(seconds: 8));

        if (res.statusCode == 200) {
          final codec = await ui.instantiateImageCodec(
            res.bodyBytes,
            targetWidth: size.toInt() * 2,
          );
          image = (await codec.getNextFrame()).image;
        }
      } catch (e) {
        log('load avatar image error: $e');
      }
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);
    const radius = size / 2;
    const innerRadius = radius - border;

    canvas.drawCircle(
      center.translate(0, 2),
      radius - 1,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawCircle(center, radius - 2, Paint()..color = color);

    final innerRect = Rect.fromCircle(center: center, radius: innerRadius - 2);

    if (image != null) {
      canvas.save();
      canvas.clipPath(Path()..addOval(innerRect));
      paintImage(
        canvas: canvas,
        rect: innerRect,
        image: image,
        fit: BoxFit.cover,
      );
      canvas.restore();
    } else {
      canvas.drawCircle(center, innerRadius - 2, Paint()..color = Colors.white);

      final tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: TextStyle(
            color: color,
            fontSize: 48,
            fontWeight: FontWeight.w700,
          ),
        ),
       textDirection: ui.TextDirection.ltr,
      )..layout();

      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }


  LatLng? get _customerLatLng {
    final lat = order?.address?.latitude;
    final lng = order?.address?.longitude;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  LatLng? get _riderLatLng {
    final p = currentRiderPosition;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  /// ระยะห่างเป็น กม. : คำนวณสดจากตำแหน่งในเครื่อง ถ้าไม่มีให้ใช้ค่าที่ backend ส่งมา
  double? get _distanceKm {
    final c = _customerLatLng;
    final r = _riderLatLng;

    if (c != null && r != null) {
      final meters = Geolocator.distanceBetween(
        r.latitude,
        r.longitude,
        c.latitude,
        c.longitude,
      );
      return meters / 1000;
    }
    return _serverDistanceKm;
  }

  String get _distanceText {
    final km = _distanceKm;
    if (km == null) return 'กำลังหาตำแหน่ง...';
    if (km < 1) return '${(km * 1000).round()} ม.';
    return '${km.toStringAsFixed(1)} กม.';
  }


  String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('d MMM yyyy เวลา HH:mm น.', 'th').format(dt);
  }

  Widget buildCard(IconData icon, String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF29ABE2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFF29ABE2)),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget buildRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FF),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          
          const Text(
            'ระยะห่างจากคุณถึงลูกค้า',
            style: TextStyle(fontSize: 13, color: Colors.black54),
          ),
          const Spacer(),
          Text(
            _distanceText,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildMapCard() {
    final customerPosition = _customerLatLng;
    final riderPosition = _riderLatLng;

    if (customerPosition == null) {
      return buildCard(
        Icons.map_rounded,
        'ตำแหน่งลูกค้าและพนักงานรับส่ง',
        const Text(
          'ไม่มีพิกัดลูกค้า',
          style: TextStyle(fontSize: 14, color: Colors.black54),
        ),
      );
    }

    final initialTarget = riderPosition != null
        ? LatLng(
            (customerPosition.latitude + riderPosition.latitude) / 2,
            (customerPosition.longitude + riderPosition.longitude) / 2,
          )
        : customerPosition;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('customer_location'),
        position: customerPosition,
        anchor: const Offset(0.5, 0.5),
        icon: _customerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(
          title: order?.customer?.fullname ?? 'ลูกค้า',
          snippet: 'ตำแหน่งลูกค้า',
        ),
      ),
      if (riderPosition != null)
        Marker(
          markerId: const MarkerId('rider_current_location'),
          position: riderPosition,
          anchor: const Offset(0.5, 0.5),
          icon: _riderIcon ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(
            title: _riderName,
            snippet: 'ตำแหน่งปัจจุบันของคุณ',
          ),
        ),
    };

    return buildCard(
      Icons.map_rounded,
      'ตำแหน่งลูกค้าและพนักงานรับส่ง',
      Column(
        children: [
          _buildDistanceBar(),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialTarget,
                      zoom: 13,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      _fitMapToBounds();
                    },
                    markers: markers,
                    // ให้แผนที่รับท่าทางลากเองได้ แม้อยู่ใน SingleChildScrollView
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: true,
                    mapToolbarEnabled: false,
                    // ปิด lite mode เพราะ lite mode เป็นภาพนิ่ง ใช้กับ real-time ไม่ได้
                    liteModeEnabled: false,
                    compassEnabled: false,
                    buildingsEnabled: false,
                    trafficEnabled: false,
                    indoorViewEnabled: false,
                    myLocationEnabled: false,
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Material(
                      color: Colors.white,
                      elevation: 2,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _fitMapToBounds,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.center_focus_strong_rounded,
                            size: 20,
                            color: _blue,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _fitMapToBounds() {
    final controller = _mapController;
    final customerPosition = _customerLatLng;
    if (controller == null || customerPosition == null) return;

    final riderPosition = _riderLatLng;

    if (riderPosition == null) {
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: customerPosition, zoom: 15),
        ),
      );
      return;
    }

    _didFitBounds = true;

    double southLat = customerPosition.latitude < riderPosition.latitude
        ? customerPosition.latitude
        : riderPosition.latitude;
    double northLat = customerPosition.latitude > riderPosition.latitude
        ? customerPosition.latitude
        : riderPosition.latitude;
    double westLng = customerPosition.longitude < riderPosition.longitude
        ? customerPosition.longitude
        : riderPosition.longitude;
    double eastLng = customerPosition.longitude > riderPosition.longitude
        ? customerPosition.longitude
        : riderPosition.longitude;

    final latDiff = northLat - southLat;
    final lngDiff = eastLng - westLng;

    if (latDiff < 0.002) {
      southLat -= 0.001;
      northLat += 0.001;
    } else {
      southLat -= latDiff * 0.25;
      northLat += latDiff * 0.25;
    }

    if (lngDiff < 0.002) {
      westLng -= 0.001;
      eastLng += 0.001;
    } else {
      westLng -= lngDiff * 0.25;
      eastLng += lngDiff * 0.25;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(southLat, westLng),
      northeast: LatLng(northLat, eastLng),
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted || _mapController == null) return;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final o = order;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
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
          'รายละเอียดออเดอร์',
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
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF29ABE2)),
            )
          : error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: fetchOrderDetail,
                        child: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
                )
              : o == null
                  ? const Center(child: Text('ไม่พบข้อมูลออเดอร์'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF29ABE2).withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'หมายเลขออเดอร์',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '#${(o.orderId ?? widget.orderId).toUpperCase().substring(0, (o.orderId ?? widget.orderId).length.clamp(0, 8))}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 26,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today_rounded,
                                      color: Colors.white70,
                                      size: 13,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      formatDate(o.orderDatetime),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),

                          if (o.customer != null || o.address != null)
                            buildCard(
                              Icons.person_rounded,
                              'ข้อมูลลูกค้า',
                              Column(
                                children: [
                                  if (o.customer != null) ...[
                                    buildRow(
                                        'ชื่อ', o.customer?.fullname ?? '-'),
                                    buildRow(
                                        'เบอร์โทร', o.customer?.phone ?? '-'),
                                  ],
                                  if (o.address != null)
                                    buildRow(
                                      'ที่อยู่',
                                      o.address?.addressText ?? '-',
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 12),

                          buildMapCard(),
                          const SizedBox(height: 12),

                          buildCard(
                            Icons.local_laundry_service_rounded,
                            'รายละเอียดบริการ',
                            Column(
                              children: [
                                buildRow(
                                  'รูปแบบบริการ',
                                  o.serviceType == 'wash_dry'
                                      ? 'ซักและอบ'
                                      : o.serviceType == 'wash'
                                          ? 'ซักอย่างเดียว'
                                          : o.serviceType == 'dry'
                                              ? 'อบอย่างเดียว'
                                              : '-',
                                ),
                                buildRow(
                                  'น้ำหนักผ้า',
                                  o.washDryWeight != null
                                      ? '${o.washDryWeight} กิโลกรัม'
                                      : '-',
                                  valueColor: const Color(0xFF29ABE2),
                                ),
                                buildRow(
                                  'น้ำยาซัก',
                                  o.detergentOption == 'detergent'
                                      ? 'ใช้น้ำยาซักผ้าของร้าน'
                                      : o.detergentOption == 'no_detergent'
                                          ? 'ไม่ใช้น้ำยาซัก'
                                          : '-',
                                ),
                                buildRow('หมายเหตุ', o.note ?? '-'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }
}