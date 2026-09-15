import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_detail_images_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_detail_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_review_store.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_order_screen.dart';

class CustomerStoreDetailScreen extends StatefulWidget {
  final String storeId;
  const CustomerStoreDetailScreen({super.key, required this.storeId});

  @override
  State<CustomerStoreDetailScreen> createState() => _CustomerStoreDetailState();
}

class _CustomerStoreDetailState extends State<CustomerStoreDetailScreen> {
  static const _kPrimary = Color(0xFF0EA5E9);
  static const _kAccent = Color(0xFF0593FF);
  static const _kTextDark = Color(0xFF0D1B2A);
  static const _kTextGray = Color(0xFF6B7280);
  static const _kTextLight = Color(0xFFB0B7C3);
  static const _kAmber = Color(0xFFFBBF24);
  static const _kDivider = Color(0xFFF1F5F9);
  static const _kDanger = Color(0xFFE53935);
  static const _kDangerBg = Color(0xFFFFEBEB);
  static const _kSuccess = Color(0xFF1DB954);
  static const _kWarning = Color(0xFFFF9500);
  static const _kFacebook = Color(0xFF1877F2);
  static const _kLine = Color(0xFF06C755);
  static const _kBg = Color(0xFFF2F4F7);

  String _apiUrl = '';
  StoreDetail? _store;
  List<StoreImage> _storeImages = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _activeTab = 0;
  int _currentImageIndex = 0;
  final _pageController = PageController();
  GoogleMapController? _mapController;
  Stream<int>? _queueStream;

  StoreReviewsResponse? _reviewsData;
  bool _isLoadingReviews = true;


  int? _selectedRatingFilter;

  static const _pendingStatuses = [
    'waiting_wash',
    'waiting_payment',
    'washing',
    'waiting_dry',
    'drying',
    'waiting_delivery',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final config = await Configuration.getConfig();
      _apiUrl = config['apiEndpoint']?.toString() ?? '';
    } catch (_) {}

    if (!mounted) return;

    _queueStream = FirebaseFirestore.instance
        .collection('orders')
        .where(
          'store_id',
          isEqualTo: FirebaseFirestore.instance.doc('stores/${widget.storeId}'),
        )
        .where('status', whereIn: _pendingStatuses)
        .snapshots()
        .map((snap) => snap.docs.length);

    await Future.wait([_fetchProfile(), _fetchImages(), _fetchReviews()]);
  }

  void _retry() {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isLoadingReviews = true;
      _selectedRatingFilter = null;
    });
    _loadData();
  }

  Future<void> _fetchProfile() async {
    if (_apiUrl.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถโหลดการตั้งค่าได้';
      });
      return;
    }
    try {
      final res = await GetConnect().get(
        '$_apiUrl/store/customer/profile/${widget.storeId}',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (res.statusCode == 200 && res.body['ok'] == true) {
          _store = StoreDetail.fromJson(res.body['data']);
        } else {
          _errorMessage = res.body['message'] ?? 'เกิดข้อผิดพลาด';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้';
      });
    }
  }

  Future<void> _fetchImages() async {
    if (_apiUrl.isEmpty) return;
    try {
      final res = await GetConnect().get(
        '$_apiUrl/store/images/${widget.storeId}',
      );
      if (!mounted) return;
      if (res.statusCode == 200 && res.body['ok'] == true) {
        final list = res.body['images'] as List? ?? [];
        setState(
          () => _storeImages = list.map((e) => StoreImage.fromJson(e)).toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> _fetchReviews() async {
    if (_apiUrl.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoadingReviews = false);
      return;
    }
    try {
      final res = await GetConnect().get(
        '$_apiUrl/order/store/${widget.storeId}/reviews',
      );
      if (!mounted) return;
      setState(() {
        _isLoadingReviews = false;
        if (res.statusCode == 200 && res.body['data'] != null) {
          _reviewsData = StoreReviewsResponse.fromJson(res.body['data']);
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingReviews = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return _kSuccess;
      case 'TEMP_CLOSED':
        return _kWarning;
      default:
        return _kDanger;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'OPEN':
        return 'เปิดร้าน';
      case 'TEMP_CLOSED':
        return 'ปิดชั่วคราว';
      default:
        return 'ปิดร้าน';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _kBg,
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
          leading: IconButton(
            onPressed: Get.back,
            icon: const Icon(Icons.arrow_back_ios),
          ),
          
          title: const Text(
            'รายละเอียดร้านค้า',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? _loadingIndicator()
            : _errorMessage != null
                ? _errorView()
                : _body(),
        bottomNavigationBar: (!_isLoading && _errorMessage == null)
            ? _bookingButton()
            : null,
      ),
    );
  }

  Widget _loadingIndicator({double strokeWidth = 2.5}) {
    return Center(
      child: CircularProgressIndicator(
        color: _kPrimary,
        strokeWidth: strokeWidth,
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kDangerBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: _kDanger,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _kTextGray),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final store = _store!;
    final images = _storeImages.isNotEmpty
        ? _storeImages.map((e) => e.imagePath).toList()
        : store.profileImage.isNotEmpty
            ? [store.profileImage]
            : <String>[];

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _imageCarousel(images)),
        SliverToBoxAdapter(child: _storeHeader(store)),
        SliverToBoxAdapter(child: _tabBar()),
      ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: SingleChildScrollView(
          key: ValueKey(_activeTab),
          padding: const EdgeInsets.only(bottom: 110),
          child: _activeTab == 0 ? _infoTab(store) : _reviewTab(),
        ),
      ),
    );
  }

  Widget _imageCarousel(List<String> images) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          images.isNotEmpty
              ? PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (i) => setState(() => _currentImageIndex = i),
                  itemBuilder: (_, i) => Image.network(
                    images[i],
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : Container(
                            color: const Color(0xFFCFD8DC),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: _kPrimary,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  ),
                )
              : _imagePlaceholder(),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
            ),
          ),
          if (images.length > 1) ...[
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  images.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == i ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == i
                          ? Colors.white
                          : Colors.white.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 64,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentImageIndex + 1} / ${images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
        color: const Color(0xFFCFD8DC),
        child: const Center(
          child: Icon(
            Icons.store_mall_directory_rounded,
            size: 72,
            color: Colors.white54,
          ),
        ),
      );

  Widget _storeHeader(StoreDetail store) {
    final avgStoreRating = _reviewsData?.avgRating ?? 0.0;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  store.storeName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 16,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      avgStoreRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(
                icon: Icons.circle,
                iconSize: 8,
                label: _statusLabel(store.status),
                textColor: _statusColor(store.status),
                bgColor: _statusColor(store.status).withOpacity(0.12),
              ),
              _chip(
                icon: Icons.access_time_rounded,
                label: '${store.openingHours} – ${store.closedHours}',
              ),
              _chip(
                icon: Icons.local_laundry_service_rounded,
                label: '${store.serviceRadius.toStringAsFixed(1)} กม.',
              ),
              StreamBuilder<int>(
                stream: _queueStream,
                builder: (context, snap) {
                  final count = snap.data ?? 0;
                  final loading =
                      snap.connectionState == ConnectionState.waiting;
                  final hasQueue = count > 0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: hasQueue ? _kDivider : _kAccent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_alt_rounded,
                          size: 13,
                          color: hasQueue ? _kAccent : Colors.white,
                        ),
                        const SizedBox(width: 6),
                        loading
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                hasQueue ? '$count คิว' : 'ว่าง',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: hasQueue ? _kAccent : Colors.white,
                                ),
                              ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    double iconSize = 13,
    required String label,
    Color textColor = _kTextGray,
    Color bgColor = const Color(0xFFF3F4F6),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: textColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabBar() {
    return Container(
      color: Colors.white,
      child: Row(
        children: ['ข้อมูลร้าน', 'รีวิว'].asMap().entries.map((e) {
          final isActive = _activeTab == e.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = e.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive ? _kPrimary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isActive ? _kPrimary : _kTextGray,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _infoTab(StoreDetail store) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ตำแหน่งร้าน',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: _kTextDark,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 180,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(store.latitude, store.longitude),
                      zoom: 15,
                    ),
                    onMapCreated: (c) => _mapController = c,
                    markers: {
                      Marker(
                        markerId: const MarkerId('store'),
                        position: LatLng(store.latitude, store.longitude),
                        infoWindow: InfoWindow(title: store.storeName),
                      ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    gestureRecognizers: {
                      Factory<OneSequenceGestureRecognizer>(
                        () => EagerGestureRecognizer(),
                      ),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _infoSection('ข้อมูลติดต่อ', [
          _infoRow(icon: Icons.location_on_rounded, text: store.address),
          _infoRow(icon: Icons.phone_rounded, text: store.phone),
          _infoRow(icon: Icons.email_rounded, text: store.email, isLink: true),
          _infoRow(
            icon: Icons.facebook_rounded,
            text: store.facebook,
            iconColor: _kFacebook,
          ),
          _infoRow(
            icon: Icons.chat_bubble_rounded,
            text: store.lineId,
            customIcon: const FaIcon(
              FontAwesomeIcons.line,
              color: _kLine,
              size: 20,
            ),
            iconColor: _kLine,
            isLast: true,
          ),
        ]),
        const SizedBox(height: 6),
        _infoSection('เกี่ยวกับร้าน', [
          _infoRow(
            icon: Icons.local_laundry_service_rounded,
            text:
                'เครื่องซัก ${store.machineWashCount} เครื่อง  เครื่องอบ ${store.machineDryCount} เครื่อง',
          ),
          _infoRow(
            icon: Icons.my_location_rounded,
            customIcon: const FaIcon(
              FontAwesomeIcons.locationCrosshairs,
              color: _kPrimary,
              size: 18,
            ),
            iconColor: _kPrimary,
            text: 'รับส่งสูงสุด ${store.serviceRadius.toStringAsFixed(0)} กม.',
            isLast: true,
          ),
_infoRow(
  icon: Icons.local_laundry_service_rounded, // ไม่ถูกใช้เพราะมี customIcon
  customIcon: const FaIcon(
    FontAwesomeIcons.bottleDroplet,
    color: _kPrimary,
    size: 18,
  ),
  iconColor: _kPrimary,
  text: 'ค่าน้ำยาซัก ${store.detergentprice.toStringAsFixed(0)} บาท',
  isLast: true,
),
_infoRow(
  icon: Icons.delivery_dining_outlined,
  iconColor: _kPrimary,
  text: 'ค่าส่ง ต่ำสุด ${store.min_delivery_price.toStringAsFixed(0)} - สูงสุด ${store.max_delivery_price.toStringAsFixed(0)} บาท',
  isLast: false,
),
        ]),
      ],
    );
  }

  Widget _infoSection(String title, List<Widget> items) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: _kTextDark,
            ),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String text,
    Color iconColor = _kPrimary,
    bool isLink = false,
    bool isLast = false,
    Widget? customIcon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 8 : 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: customIcon ?? Icon(icon, color: iconColor, size: 19),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: isLink ? iconColor : _kTextDark,
                decoration: isLink ? TextDecoration.underline : null,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reviews tab (now with star-rating filter) ──────────────────────────

  List<ReviewItem> _filteredReviews(List<ReviewItem> reviews) {
    if (_selectedRatingFilter == null) return reviews;
    return reviews
        .where((r) => r.rating.round() == _selectedRatingFilter)
        .toList();
  }

  void _toggleRatingFilter(int star) {
    setState(() {
      _selectedRatingFilter = _selectedRatingFilter == star ? null : star;
    });
  }

  Widget _reviewTab() {
    if (_isLoadingReviews) {
      return _loadingIndicator();
    }

    final data = _reviewsData;
    if (data == null || data.reviews.isEmpty) {
      return _reviewEmptyView();
    }

    final filtered = _filteredReviews(data.reviews);

    return Column(
      children: [
        _reviewSummaryCard(data),
        if (_selectedRatingFilter != null) _activeFilterBar(),
        const SizedBox(height: 6),
        if (filtered.isEmpty)
          _reviewEmptyView(filteredByRating: true)
        else
          ...filtered.map((r) => _reviewCard(r)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _activeFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _kAmber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 15, color: _kAmber),
                const SizedBox(width: 4),
                Text(
                  '$_selectedRatingFilter ดาว',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _selectedRatingFilter = null),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 15, color: _kTextGray),
                SizedBox(width: 2),
                Text(
                  'ล้างตัวกรอง',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _kTextGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _reviewEmptyView({bool filteredByRating = false}) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              filteredByRating
                  ? Icons.filter_alt_off_rounded
                  : Icons.rate_review_rounded,
              size: 34,
              color: _kPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            filteredByRating
                ? 'ไม่มีรีวิว $_selectedRatingFilter ดาว'
                : 'ยังไม่มีรีวิว',
            style: const TextStyle(
              color: _kTextGray,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            filteredByRating ? 'ลองเลือกจำนวนดาวอื่น' : 'เป็นคนแรกที่รีวิวร้านนี้',
            style: const TextStyle(color: _kTextLight, fontSize: 13),
          ),
          if (filteredByRating) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _selectedRatingFilter = null),
              child: const Text(
                'ดูรีวิวทั้งหมด',
                style: TextStyle(
                  color: _kPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _starRow(num rating, {double size = 14, double spacing = 1.5}) {
    final filledCount = rating.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < filledCount;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_border_rounded,
            color: _kAmber,
            size: size,
          ),
        );
      }),
    );
  }

  Widget _reviewSummaryCard(StoreReviewsResponse data) {
    final distribution = _ratingDistribution(data.reviews);
    final maxCount = distribution.values.isEmpty
        ? 0
        : distribution.values.reduce((a, b) => a > b ? a : b);

    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => setState(() => _selectedRatingFilter = null),
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  data.avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _starRow(data.avgRating, size: 18),
                const SizedBox(height: 6),
                Text(
                  '${data.reviewCount} รีวิว',
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedRatingFilter == null
                        ? _kPrimary
                        : _kTextGray,
                    fontWeight: _selectedRatingFilter == null
                        ? FontWeight.w700
                        : FontWeight.w500,
                    decoration: _selectedRatingFilter == null
                        ? TextDecoration.underline
                        : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              children: List.generate(5, (i) {
                final star = 5 - i;
                final count = distribution[star] ?? 0;
                final ratio = maxCount > 0 ? count / maxCount : 0.0;
                final isSelected = _selectedRatingFilter == star;

                return GestureDetector(
                  onTap: count == 0 ? null : () => _toggleRatingFilter(star),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kAmber.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$star',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Color(0xFF92400E) : _kTextGray,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 12,
                          color: _kAmber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 6,
                              backgroundColor: _kDivider,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                _kAmber,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 16,
                          child: Text(
                            '$count',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? Color(0xFF92400E) : _kTextGray,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Map<int, int> _ratingDistribution(List<ReviewItem> reviews) {
    final Map<int, int> counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
    for (final r in reviews) {
      final rating = r.rating.round();
      if (rating >= 1 && rating <= 5) {
        counts[rating] = (counts[rating] ?? 0) + 1;
      }
    }
    return counts;
  }

  Widget _reviewCard(ReviewItem r) {
    final dateStr = r.reviewedAt != null
        ? DateFormat('d MMM yyyy', 'th').format(r.reviewedAt!)
        : '';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFE3F4FC),
                backgroundImage: r.customerProfileImage.isNotEmpty
                    ? NetworkImage(r.customerProfileImage)
                    : null,
                child: r.customerProfileImage.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: _kPrimary,
                        size: 20,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customerFullname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _starRow(r.rating, size: 14, spacing: 0),
                        if (dateStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            dateStr,
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kTextLight,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.comment != null && r.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              r.comment!,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF3D4A5C),
                height: 1.4,
              ),
            ),
          ],
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Divider(height: 1, color: _kDivider),
          ),
        ],
      ),
    );
  }

  Widget _bookingButton() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: () =>
              Get.to(() => CustomerOrderScreen(storeId: widget.storeId)),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: const Text(
            'เลือกบริการ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ),
    );
  }
}