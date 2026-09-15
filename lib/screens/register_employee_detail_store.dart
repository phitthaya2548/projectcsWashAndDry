import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_detail_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_list_register_employee_store.dart';
import 'package:wash_and_dry/service/session_service.dart';

class StoreDetailEmployeeScreen extends StatefulWidget {
  final String storeId;

  const StoreDetailEmployeeScreen({super.key, required this.storeId});

  @override
  State<StoreDetailEmployeeScreen> createState() =>
      _StoreDetailEmployeeScreenState();
}

class _StoreDetailEmployeeScreenState extends State<StoreDetailEmployeeScreen> {
  static const _kPrimary = Color(0xFF0EA5E9);
  static const _kTextDark = Color(0xFF0D1B2A);
  static const _kTextGray = Color(0xFF6B7280);
  static const _kTextLight = Color(0xFFB0B7C3);
  static const _kAmber = Color(0xFFFBBF24);
  static const _kDivider = Color(0xFFF1F5F9);
  static const _kDanger = Color(0xFFE53935);
  static const _kDangerBg = Color(0xFFFFEBEB);
  static const _kFacebook = Color(0xFF1877F2);
  static const _kLine = Color(0xFF06C755);
  static const _kBg = Color(0xFFF2F4F7);
  static const _kGreen = Color(0xFF16A34A);
  static const _kPurple = Color(0xFF7C3AED);

  final PageController _pageController = PageController();
  final Session _session = Session();

  GoogleMapController? _mapController;

  int _activeTab = 0;
  int _currentImageIndex = 0;
  int? _selectedRatingFilter;

  bool _isApplying = false;
  bool _loadingImages = true;
  bool _loadingReviews = true;
  bool _isLoading = true;

  String? _sessionRole;
  String? _errorMessage;
  String url = '';

  StoreDetail? _store;
  List<StoreImageItem> _images = [];
  List<StoreReviewItem> _reviews = [];

  double _avgRating = 0;
  int _reviewCount = 0;

  StoreDetail get store => _store!;

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
      url = config['apiEndpoint']?.toString() ?? '';
    } catch (_) {}

    if (url.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadingImages = false;
        _loadingReviews = false;
        _errorMessage = 'ไม่สามารถโหลดการตั้งค่าได้';
      });
      return;
    }

    try {
      _sessionRole = await _session.getRole();
    } catch (_) {
      _sessionRole = null;
    }

    await Future.wait([_fetchProfile(), _fetchImages(), _fetchReviews()]);
  }

  Future<void> _fetchProfile() async {
    try {
      final res = await GetConnect().get(
        '$url/store/customer/profile/${widget.storeId}',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;

        if (res.statusCode == 200 && res.body['ok'] == true) {
          _store = StoreDetail.fromJson(res.body['data']);
        } else {
          _errorMessage = res.body['message']?.toString() ?? 'เกิดข้อผิดพลาด';
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
    try {
      final uri = Uri.parse('$url/store/images/${widget.storeId}');

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;

        if (json['ok'] == true) {
          final list = json['images'] as List<dynamic>? ?? [];
          final images = list
              .map((e) => StoreImageItem.fromJson(e as Map<String, dynamic>))
              .toList();

          if (mounted) {
            setState(() {
              _images = images;
            });
          }
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loadingImages = false;
      });
    }
  }

  Future<void> _fetchReviews() async {
    try {
      final uri = Uri.parse('$url/order/store/${widget.storeId}/reviews');

      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>? ?? {};
        final list = data['reviews'] as List<dynamic>? ?? [];

        final reviews = list
            .map((e) => StoreReviewItem.fromJson(e as Map<String, dynamic>))
            .toList();

        final avgRating = (data['avg_rating'] as num?)?.toDouble() ?? 0;
        final reviewCount =
            (data['review_count'] as num?)?.toInt() ?? reviews.length;

        if (mounted) {
          setState(() {
            _reviews = reviews;
            _avgRating = avgRating;
            _reviewCount = reviewCount;
          });
        }
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _loadingReviews = false;
      });
    }
  }

  void _retry() {
    if (!mounted) return;

    setState(() {
      _activeTab = 0;
      _currentImageIndex = 0;
      _selectedRatingFilter = null;
      _isLoading = true;
      _loadingImages = true;
      _loadingReviews = true;
      _errorMessage = null;
      _store = null;
      _images = [];
      _reviews = [];
      _avgRating = 0;
      _reviewCount = 0;
    });

    _loadData();
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
            : _errorMessage != null || _store == null
            ? _errorView()
            : _body(),
        bottomNavigationBar:
            !_isLoading &&
                _errorMessage == null &&
                _store != null &&
                (_sessionRole == 'rider' || _sessionRole == 'laundry_staff')
            ? _buildBottomActions()
            : null,
      ),
    );
  }

  Widget _loadingIndicator() {
    return const Center(
      child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
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
              _errorMessage ?? 'ไม่พบข้อมูลร้านค้า',
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
    final images = _images.isNotEmpty
        ? _images.map((e) => e.imagePath).toList()
        : store.profileImage.isNotEmpty
        ? [store.profileImage]
        : <String>[];

    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(child: _imageCarousel(images)),
        SliverToBoxAdapter(child: _storeHeader()),
        SliverToBoxAdapter(child: _tabBar()),
      ],
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: SingleChildScrollView(
          key: ValueKey(_activeTab),
          padding: const EdgeInsets.only(bottom: 24),
          child: _activeTab == 0 ? _infoTab() : _reviewTab(),
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
                  onPageChanged: (index) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  itemBuilder: (_, index) {
                    return _networkImage(images[index]);
                  },
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
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _currentImageIndex == index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _currentImageIndex == index
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

  Widget _networkImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return _imagePlaceholder();
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, progress) {
        if (progress == null) {
          return child;
        }

        return Container(
          color: const Color(0xFFCFD8DC),
          child: const Center(
            child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return _imagePlaceholder();
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFCFD8DC),
      child: const Center(
        child: Icon(
          Icons.store_mall_directory_rounded,
          size: 72,
          color: Colors.white54,
        ),
      ),
    );
  }

  Widget _storeHeader() {
    final rating = _avgRating;

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
                  store.storeName.isNotEmpty ? store.storeName : '-',
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
                      rating.toStringAsFixed(1),
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
                icon: Icons.access_time_rounded,
                label: store.openingHours.isNotEmpty
                    ? '${store.openingHours} – ${store.closedHours}'
                    : '-',
              ),
              _chip(
                icon: Icons.local_shipping_rounded,
                label: '${store.serviceRadius.toStringAsFixed(1)} กม.',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required IconData icon,
    required String label,
    double iconSize = 13,
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
        children: ['ข้อมูลร้าน', 'รีวิว'].asMap().entries.map((entry) {
          final isActive = _activeTab == entry.key;

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _activeTab = entry.key;
                  _selectedRatingFilter = null;
                });
              },
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
                  entry.value,
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

  Widget _infoTab() {
    final currency = NumberFormat.currency(
      locale: 'th_TH',
      symbol: '฿',
      decimalDigits: 0,
    );

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
              _buildMap(),
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
            icon: Icons.my_location_rounded,
            customIcon: const FaIcon(
              FontAwesomeIcons.locationCrosshairs,
              color: _kPrimary,
              size: 18,
            ),
            iconColor: _kPrimary,
            text: 'รับส่งสูงสุด ${store.serviceRadius.toStringAsFixed(0)} กม.',
          ),
          _infoRow(
            icon: Icons.local_laundry_service_rounded,
            iconColor: _kPrimary,
            text: 'เครื่องซัก ${store.machineWashCount} เครื่อง',
          ),
          _infoRow(
            icon: Icons.local_laundry_service_rounded,
            iconColor: _kPrimary,
            text: 'เครื่องอบ ${store.machineDryCount} เครื่อง',
          ),
          _infoRow(
  icon: Icons.local_laundry_service_rounded, // ไม่ถูกใช้เพราะมี customIcon
  customIcon: const FaIcon(
    FontAwesomeIcons.bottleDroplet,
    color: _kPrimary,
    size: 18,
  ),
  iconColor: _kPrimary,
  text: 'ราคาน้ำยาซัก ${currency.format(store.detergentprice)}',
  isLast: true,
),
        ]),
      ],
    );
  }

  Widget _buildMap() {
    if (store.latitude == 0 && store.longitude == 0) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.map_outlined, size: 42, color: _kTextLight),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: 180,
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(store.latitude, store.longitude),
            zoom: 15,
          ),
          onMapCreated: (controller) {
            _mapController = controller;
          },
          markers: {
            Marker(
              markerId: MarkerId(widget.storeId),
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
    final display = text.isNotEmpty ? text : '-';

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
              display,
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

  List<StoreReviewItem> _filteredReviews() {
    if (_selectedRatingFilter == null) {
      return _reviews;
    }

    return _reviews
        .where((review) => review.rating.round() == _selectedRatingFilter)
        .toList();
  }

  void _toggleRatingFilter(int star) {
    setState(() {
      _selectedRatingFilter = _selectedRatingFilter == star ? null : star;
    });
  }

  Widget _reviewTab() {
    if (_loadingReviews) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 64),
        child: Center(
          child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5),
        ),
      );
    }

    if (_reviews.isEmpty) {
      return _reviewEmptyView();
    }

    final filtered = _filteredReviews();

    return Column(
      children: [
        _reviewSummaryCard(),
        if (_selectedRatingFilter != null) _activeFilterBar(),
        const SizedBox(height: 6),
        if (filtered.isEmpty)
          _reviewEmptyView(filteredByRating: true)
        else
          ...filtered.map(_reviewCard),
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
            onTap: () {
              setState(() {
                _selectedRatingFilter = null;
              });
            },
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
            filteredByRating
                ? 'ลองเลือกจำนวนดาวอื่น'
                : 'ยังไม่มีผู้ใช้รีวิวร้านนี้',
            style: const TextStyle(color: _kTextLight, fontSize: 13),
          ),
          if (filteredByRating) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedRatingFilter = null;
                });
              },
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
      children: List.generate(5, (index) {
        final filled = index < filledCount;

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

  Widget _reviewSummaryCard() {
    final rating = _avgRating;
    final total = _reviewCount;
    final distribution = _ratingDistribution();

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
            onTap: () {
              setState(() {
                _selectedRatingFilter = null;
              });
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                    color: _kTextDark,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 8),
                _starRow(rating, size: 18),
                const SizedBox(height: 6),
                Text(
                  '$total รีวิว',
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
              children: List.generate(5, (index) {
                final star = 5 - index;
                final count = distribution[star] ?? 0;
                final ratio = maxCount > 0 ? count / maxCount : 0.0;
                final isSelected = _selectedRatingFilter == star;

                return GestureDetector(
                  onTap: count == 0
                      ? null
                      : () {
                          _toggleRatingFilter(star);
                        },
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
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: isSelected
                                ? const Color(0xFF92400E)
                                : _kTextGray,
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
                              color: isSelected
                                  ? const Color(0xFF92400E)
                                  : _kTextGray,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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

  Map<int, int> _ratingDistribution() {
    final counts = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0};

    for (final review in _reviews) {
      final rating = review.rating.round();

      if (rating >= 1 && rating <= 5) {
        counts[rating] = (counts[rating] ?? 0) + 1;
      }
    }

    return counts;
  }

  Widget _reviewCard(StoreReviewItem review) {
    final dateStr = review.reviewedAt != null
        ? DateFormat('d MMM yyyy', 'th').format(review.reviewedAt!)
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
                backgroundImage: review.reviewerImage.isNotEmpty
                    ? NetworkImage(review.reviewerImage)
                    : null,
                child: review.reviewerImage.isEmpty
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
                      review.reviewerName.isNotEmpty
                          ? review.reviewerName
                          : 'ผู้ใช้ไม่ระบุชื่อ',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        _starRow(review.rating, size: 14, spacing: 0),
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
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.comment,
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

  Widget _buildBottomActions() {
    final isRider = _sessionRole == 'rider';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: isRider
              ? OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: _kPrimary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isApplying
                      ? null
                      : () => _applyAsEmployee(role: 'rider'),
                  label: _isApplying
                      ? _buttonSpinner(_kPrimary)
                      : const Text(
                          'สมัครพนักงานไรเดอร์',
                          style: TextStyle(
                            color: _kPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                )
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isApplying
                      ? null
                      : () => _applyAsEmployee(role: 'laundry'),
                  label: _isApplying
                      ? _buttonSpinner(Colors.white)
                      : const Text(
                          'สมัครพนักงานซักอบ',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
        ),
      ),
    );
  }

  Widget _buttonSpinner(Color color) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2, color: color),
    );
  }

  Future<void> _applyAsEmployee({required String role}) async {
    final sessionRole = await _session.getRole();

    final expectedSessionRole = role == 'rider' ? 'rider' : 'laundry_staff';

    if (sessionRole == null ||
        sessionRole.isEmpty ||
        sessionRole != expectedSessionRole) {
      _showSnack(
        title: 'แจ้งเตือน',
        message: sessionRole == null || sessionRole.isEmpty
            ? 'กรุณาเข้าสู่ระบบก่อนสมัคร'
            : 'บัญชีนี้ไม่สามารถสมัครเป็น${role == 'rider' ? 'ไรเดอร์' : 'พนักงานซักอบ'}ได้',
        type: _SnackType.warning,
      );
      return;
    }

    final userId = role == 'rider'
        ? await _session.getRiderId()
        : await _session.getStaffId();

    if (userId == null || userId.isEmpty) {
      _showSnack(
        title: 'แจ้งเตือน',
        message: 'ไม่พบข้อมูลบัญชี กรุณาเข้าสู่ระบบใหม่อีกครั้ง',
        type: _SnackType.warning,
      );
      return;
    }

    String apiUrl = url;

    if (apiUrl.isEmpty) {
      try {
        final config = await Configuration.getConfig();

        apiUrl = config['apiEndpoint']?.toString() ?? '';
      } catch (_) {}
    }

    if (apiUrl.isEmpty) {
      _showSnack(
        title: 'แจ้งเตือน',
        message: 'ไม่สามารถโหลดการตั้งค่าได้',
        type: _SnackType.error,
      );
      return;
    }

    final endpoint = role == 'rider'
        ? '$apiUrl/employee_regis_store/rider/store/$userId'
        : '$apiUrl/employee_regis_store/staff/store/$userId';

    setState(() {
      _isApplying = true;
    });

    try {
      final res = await GetConnect().put(endpoint, {
        'store_id': widget.storeId,
      });

      if (res.statusCode == 200 && res.body['ok'] == true) {
        _showSnack(
          title: 'สำเร็จ',
          message:
              res.body['message']?.toString() ??
              'ส่งคำขอสำเร็จ กรุณารอร้านค้ายืนยัน',
          type: _SnackType.success,
        );
      } else {
        _showSnack(
          title: 'ไม่สำเร็จ',
          message:
              res.body['message']?.toString() ?? 'เกิดข้อผิดพลาด กรุณาลองใหม่',
          type: _SnackType.error,
        );
      }
    } catch (_) {
      _showSnack(
        title: 'ไม่สำเร็จ',
        message: 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้',
        type: _SnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  void _showSnack({
    required String title,
    required String message,
    required _SnackType type,
  }) {
    final colors = switch (type) {
      _SnackType.success => (
        bg: const Color(0xFFE8FFF0),
        text: const Color(0xFF1DB954),
      ),
      _SnackType.warning => (
        bg: const Color(0xFFFFF7E6),
        text: const Color(0xFF92400E),
      ),
      _SnackType.error => (
        bg: const Color(0xFFFFEBEB),
        text: const Color(0xFFE53935),
      ),
    };

    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: colors.bg,
      colorText: colors.text,
    );
  }
}

enum _SnackType { success, warning, error }