import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/res_applied_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_list_register_employee_store.dart';
import 'package:wash_and_dry/screens/login_screen.dart';
import 'package:wash_and_dry/screens/register_employee_detail_store.dart';
import 'package:wash_and_dry/screens/rider/rider_edit_profile_screen.dart';
import 'package:wash_and_dry/screens/staff/staff_edit_profile_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/main_shell_rider.dart';
import 'package:wash_and_dry/widgets/main_shell_staff.dart';

enum StoreSortOption { distance, rating }

class RegiserEmployeeStore extends StatefulWidget {
  const RegiserEmployeeStore({super.key});

  @override
  State<RegiserEmployeeStore> createState() => _StoreRegisterScreenState();
}

class _StoreRegisterScreenState extends State<RegiserEmployeeStore>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF0593FF);
  static const _primaryDark = Color(0xFF0476D9);
  static const _bg = Color(0xFFF5F7FA);
  static const _success = Color(0xFF22C55E);
  static const _danger = Color(0xFFEF4444);
  static const _warning = Color(0xFFF59E0B);
  static const _cardRadius = 20.0;

  late final TabController _tabController;
  int _lastTabIndex = 0;

  String _apiUrl = '';
  String? _userId ='';
  String? _role;

  bool _loading = true;
  String? _error;
  List<StoreListItem> _stores = [];
  StoreSortOption _sortOption = StoreSortOption.distance;

  bool _locating = false;
  Position? _userPosition;
  String? _locationError;

  String? imageUrl;

  bool _loadingApplied = true;
  String? _appliedError;
  AppliedStoreData? _appliedStore;
  bool _unapplying = false;

  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _searchLoading = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 1 && _lastTabIndex != 1) {
      _fetchAppliedStore();
    }
    _lastTabIndex = _tabController.index;
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cfg = await Configuration.getConfig();
      _apiUrl = cfg['apiEndpoint']?.toString() ?? '';

      final session = Session();
      imageUrl = await session.getProfileImage() ;

      _role = await session.getRole();
      _userId = _role == 'rider'
          ? await session.getRiderId()
          : _role == 'laundry_staff'
          ? await session.getStaffId()
          : null;

      _startLocating();

      await Future.wait([_fetchStores(), _fetchAppliedStore()]);

      if (mounted) setState(() => _loading = false);
    } catch (e) {
      log('LOAD ERROR: $e');
      if (mounted) {
        setState(() {
          _error = 'โหลดข้อมูลไม่สำเร็จ';
          _loading = false;
        });
      }
    }
  }

  Future<void> _refresh() => _loadData();

  void _startLocating() {
    if (_locating || !mounted) return;
    setState(() => _locating = true);
    _getUserLocation().then((_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _applySort();
      });
    });
  }

  Future<void> _getUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _locationError = 'กรุณาเปิดบริการตำแหน่ง (Location Service)';
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _locationError = 'ไม่ได้รับอนุญาตให้เข้าถึงตำแหน่ง';
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _locationError = 'กรุณาอนุญาตการเข้าถึงตำแหน่งในตั้งค่าเครื่อง';
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && mounted) {
        setState(() {
          _userPosition = lastKnown;
          _locationError = null;
          _applySort();
        });
      }

      Position? current;
      try {
        current = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 12),
        );
      } catch (e) {
        log('GET CURRENT POSITION ERROR: $e');
      }

      if (current != null) {
        _userPosition = current;
        _locationError = null;
      } else if (lastKnown == null) {
        _locationError = 'ไม่สามารถระบุตำแหน่งได้ ลองอีกครั้ง';
      }
    } catch (e) {
      log('LOCATION ERROR: $e');
      _locationError ??= 'ไม่สามารถระบุตำแหน่งได้';
    }
  }

  void _applySort() {
    switch (_sortOption) {
      case StoreSortOption.distance:
        _sortStoresByDistance();
      case StoreSortOption.rating:
        _sortStoresByRating();
    }
  }

  void _sortStoresByDistance() {
    if (_userPosition == null || _stores.isEmpty) return;
    _stores.sort((a, b) {
      final da = _distanceToStore(a) ?? double.infinity;
      final db = _distanceToStore(b) ?? double.infinity;
      return da.compareTo(db);
    });
  }

  void _sortStoresByRating() {
    if (_stores.isEmpty) return;
    _stores.sort((a, b) {
      final ratingCompare = b.avgRating.compareTo(a.avgRating);
      if (ratingCompare != 0) return ratingCompare;
      return b.totalReviews.compareTo(a.totalReviews);
    });
  }

  void _selectSortOption(StoreSortOption option) {
    if (_sortOption == option) return;
    setState(() {
      _sortOption = option;
      _applySort();
    });
  }

  double? _distanceToStore(StoreListItem store) {
    if (_userPosition == null) return null;
    if (store.latitude == 0 && store.longitude == 0) return null;
    return Geolocator.distanceBetween(
      _userPosition!.latitude,
      _userPosition!.longitude,
      store.latitude,
      store.longitude,
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) return '-';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} ม.';
    return '${(meters / 1000).toStringAsFixed(1)} กม.';
  }

  Future<void> _fetchStores({String? search}) async {
    if (_apiUrl.isEmpty) return;

    final query = (search ?? _searchQuery).trim();
    final uri = Uri.parse(
      '$_apiUrl/employee_regis_store/stores/list',
    ).replace(queryParameters: query.isNotEmpty ? {'search': query} : null);

    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');

    final data = StoreListResponse.fromJson(jsonDecode(res.body));
    if (!mounted) return;
    setState(() {
      _stores = data.data.where((store) => store.isHiring).toList();
      _applySort();
    });
  }

  String? _appliedStorePath() {
    if (_apiUrl.isEmpty ||
        _userId == null ||
        _userId!.isEmpty ||
        _role == null) {
      return null;
    }
    final resource = _role == 'rider' ? 'rider' : 'staff';
    return '$_apiUrl/employee_regis_store/$resource/$_userId/applied/store';
  }

  Future<void> _fetchAppliedStore() async {
    final path = _appliedStorePath();

    if (path == null) {
      if (!mounted) return;
      setState(() {
        _loadingApplied = false;
        _appliedError = 'ไม่พบข้อมูลผู้ใช้';
        _appliedStore = null;
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loadingApplied = true;
      _appliedError = null;
    });

    try {
      final res = await http
          .get(Uri.parse(path))
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}');
      }

      final data = AppliedStoreResponse.fromJson(jsonDecode(res.body));
      final appliedStore = data.data;

      if (appliedStore != null) {
        final session = Session();
        await session.updateStoreId(appliedStore.storeId);
        await session.updateStatus(appliedStore.status ?? '');
      }

      if (!mounted) return;

      setState(() {
        _appliedStore = appliedStore;
        _loadingApplied = false;
      });
    } catch (e) {
      log('FETCH APPLIED STORE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _appliedError = 'โหลดข้อมูลร้านที่สมัครไม่สำเร็จ';
        _appliedStore = null;
        _loadingApplied = false;
      });
    }
  }

  Future<void> _unapplyStore() async {
    final path = _appliedStorePath();
    if (path == null || _unapplying) return;

    setState(() => _unapplying = true);

    try {
      final res = await http
          .put(Uri.parse(path))
          .timeout(const Duration(seconds: 10));

      final json = jsonDecode(res.body) as Map<String, dynamic>;

      if (res.statusCode != 200 || json['ok'] != true) {
        throw Exception(
          json['message']?.toString() ?? 'HTTP ${res.statusCode}',
        );
      }

      await Session().clearEmployeeStore();

      if (!mounted) return;

      setState(() {
        _appliedStore = null;
        _unapplying = false;
      });

      _showToast('สำเร็จ', 'ยกเลิกการสมัครร้านแล้ว', isError: false);
    } catch (e) {
      log('UNAPPLY STORE ERROR: $e');

      if (!mounted) return;

      setState(() => _unapplying = false);

      _showToast(
        'ผิดพลาด',
        'ยกเลิกการสมัครไม่สำเร็จ กรุณาลองใหม่',
        isError: true,
      );
    }
  }

  Future<void> _logout() async {
    try {
      await Session().clear();
    } catch (e) {
      log('LOGOUT ERROR: $e');
    }
    if (mounted) Get.offAll(() => const LoginScreen());
  }

  void _onSearchChanged(String value) {
    _searchQuery = value;
    setState(() {});

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _searchLoading = true);
      try {
        await _fetchStores(search: value);
      } catch (e) {
        log('SEARCH STORES ERROR: $e');
      } finally {
        if (mounted) setState(() => _searchLoading = false);
      }
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (!mounted) return;
    setState(() {
      _searchQuery = '';
      _searchLoading = true;
    });
    _fetchStores(search: '').whenComplete(() {
      if (mounted) setState(() => _searchLoading = false);
    });
  }

  void _goToStoreDetail(String storeId) {
    Get.to(() => StoreDetailEmployeeScreen(storeId: storeId));
  }

  void _goToAppliedStoreDetail(AppliedStoreData store) {
    _goToStoreDetail(store.storeId);
  }

  bool _isApprovedStatus(String? status) {
    return status == 'ONLINE' || status == 'TEMP_CLOSED';
  }

  Color _appliedStatusColor(String? status) {
    if (_isApprovedStatus(status)) return _success;
    if (status == 'pending') return _warning;
    return Colors.grey;
  }

  void _goToWork() {
    if (_role == 'rider') {
      Get.offAll(() => MainShellRider());
      return;
    }

    if (_role == 'laundry_staff') {
      Get.offAll(() => MainShellStaff());
    }
  }

  void _goToEditProfile() {
    if (_role == 'rider') {
      if (_userId == null || _userId!.isEmpty) return;
      Get.to(() => EditRiderScreen(riderId: _userId!));
    } else if (_role == 'laundry_staff') {
      if (_userId == null || _userId!.isEmpty) return;
      Get.to(() => EditLaundryStaffScreen(staffId: _userId!));
    }
  }

  void _confirmUnapply() {
    _showConfirmDialog(
      icon: Icons.delete_outline_rounded,
      iconBg: const Color(0xFFFFEBEE),
      iconColor: _danger,
      title: 'ยกเลิกการสมัครร้าน',
      message: 'คุณต้องการยกเลิกการสมัครร้านนี้ใช่หรือไม่?',
      confirmLabel: 'ยืนยัน',
      confirmColor: _danger,
      onConfirm: _unapplyStore,
    );
  }

  void _confirmLogout() {
    _showConfirmDialog(
      icon: Icons.logout_rounded,
      iconBg: const Color(0xFFFFEBEE),
      iconColor: _danger,
      title: 'ออกจากระบบ',
      message: 'คุณต้องการออกจากระบบใช่หรือไม่?',
      confirmLabel: 'ออกจากระบบ',
      confirmColor: _danger,
      onConfirm: _logout,
    );
  }

  void _showConfirmDialog({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String message,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconBg,
                ),
                child: Icon(icon, color: iconColor, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: Get.back,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        'ยกเลิก',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Get.back();
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
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
      barrierDismissible: true,
    );
  }

  void _showToast(String title, String message, {required bool isError}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: isError ? _danger : _success,
      colorText: Colors.white,
      margin: const EdgeInsets.all(14),
      borderRadius: 14,
      icon: Icon(
        isError ? Icons.error_rounded : Icons.check_circle_rounded,
        color: Colors.white,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_primary, _primaryDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'สมัครร้านค้า',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: Colors.white),
          tooltip: 'ออกจากระบบ',
          onPressed: _confirmLogout,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: ClipOval(
                  child: (imageUrl == null || imageUrl!.isEmpty)
                      ? Container(
                          color: Colors.white,
                          child: const Icon(
                            Icons.account_circle_rounded,
                            size: 32,
                            color: Color(0xFF0EA5E9),
                          ),
                        )
                      : Image.network(
                          imageUrl!,
                          width: 34,
                          height: 34,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.white,
                              child: const Icon(
                                Icons.account_circle_rounded,
                                size: 32,
                                color: Color(0xFF0EA5E9),
                              ),
                            );
                          },
                        ),
                ),
                tooltip: 'โปรไฟล์',
                onPressed: _goToEditProfile,
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tabs: const [
            Tab(text: 'ร้านค้าทั้งหมด'),
            Tab(text: 'ร้านที่สมัคร'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _refresh,
            color: _primary,
            child: _buildStoreListTab(),
          ),
          RefreshIndicator(
            onRefresh: _fetchAppliedStore,
            color: _primary,
            child: _buildAppliedTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreListTab() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [_buildErrorState(message: _error!, onRetry: _refresh)],
      );
    }

    final banner = _buildLocationBanner();

    if (_stores.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSearchField(),
          _searchQuery.isNotEmpty
              ? _buildEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'ไม่พบร้านค้าที่ตรงกับ "$_searchQuery"',
                )
              : _buildEmptyState(
                  icon: Icons.store_outlined,
                  title: 'ยังไม่มีร้านค้าที่เปิดรับสมัคร',
                ),
        ],
      );
    }

    final headerCount = 2 + (banner != null ? 1 : 0);

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      itemCount: headerCount + _stores.length,
      itemBuilder: (context, index) {
        if (index == 0) return _buildSearchField();
        if (index == 1) return _buildSortBar();

        final bannerIndex = 2;
        if (banner != null && index == bannerIndex) return banner;

        final storeIndex = index - headerCount;
        return _buildStoreCard(_stores[storeIndex]);
      },
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'ค้นหาร้านค้า (ชื่อ, ที่อยู่, เบอร์โทร)',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 20,
              color: Colors.grey,
            ),
            suffixIcon: _searchLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _primary,
                      ),
                    ),
                  )
                : (_searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Colors.grey,
                          ),
                          onPressed: _clearSearch,
                        )
                      : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    const options = [
      (StoreSortOption.distance, 'ใกล้ที่สุด'),
      (StoreSortOption.rating, 'คะแนนสูงสุด'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          for (final (option, label) in options) ...[
            GestureDetector(
              onTap: () => _selectSortOption(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _sortOption == option ? _primary : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _sortOption == option
                        ? _primary
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _sortOption == option
                            ? Colors.white
                            : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (option != options.last.$1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget? _buildLocationBanner() {
    if (_locating && _userPosition == null) {
      return _InfoBanner(
        icon: Icons.location_searching_rounded,
        color: _primary,
        text: 'กำลังค้นหาตำแหน่งของคุณ เพื่อจัดเรียงร้านที่ใกล้ที่สุด...',
      );
    }
    if (_locationError != null && _userPosition == null) {
      return _InfoBanner(
        icon: Icons.location_off_rounded,
        color: _warning,
        text: _locationError!,
        actionLabel: 'ลองอีกครั้ง',
        onAction: _startLocating,
      );
    }
    return null;
  }

  Widget _buildStoreCard(StoreListItem store) {
    final distance = _distanceToStore(store);
    final showLocatingHint =
        distance == null &&
        _locating &&
        !(store.latitude == 0 && store.longitude == 0);

    return InkWell(
      onTap: () => _goToStoreDetail(store.storeId),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _buildStoreImage(store.profileImage, size: 64, radius: 12),
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _success,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'เปิดรับ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.storeName.isNotEmpty ? store.storeName : '-',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildChip(
                        icon: Icons.star_rounded,
                        iconColor: _warning,
                        bg: const Color(0xFFFFF7E6),
                        text: store.totalReviews > 0
                            ? '${store.avgRating.toStringAsFixed(1)} (${store.totalReviews})'
                            : 'ยังไม่มีรีวิว',
                        textColor: const Color(0xFF92400E),
                      ),
                      if (distance != null)
                        _buildChip(
                          icon: Icons.near_me_rounded,
                          iconColor: _primary,
                          bg: const Color(0xFFE6F4FF),
                          text: _formatDistance(distance),
                          textColor: _primaryDark,
                        )
                      else if (showLocatingHint)
                        _buildChip(
                          icon: Icons.location_searching_rounded,
                          iconColor: Colors.grey[500]!,
                          bg: const Color(0xFFF3F4F6),
                          text: 'กำลังหาตำแหน่ง',
                          textColor: Colors.grey[600]!,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.address.isNotEmpty ? store.address : '-',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          store.openingHours.isNotEmpty
                              ? '${store.openingHours} - ${store.closedHours}'
                              : '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey.shade400,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppliedTab() {
    if (_loadingApplied) {
      return const Center(child: CircularProgressIndicator(color: _primary));
    }

    if (_appliedError != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildErrorState(
            message: _appliedError!,
            onRetry: _fetchAppliedStore,
          ),
        ],
      );
    }

    if (_appliedStore == null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildEmptyState(
            icon: Icons.assignment_late_outlined,
            title: 'คุณยังไม่ได้สมัครร้านค้าใด',
            subtitle: 'เลื่อนไปแท็บ "ร้านค้าทั้งหมด" เพื่อเลือกสมัคร',
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12, bottom: 20),
      children: [_buildAppliedStoreCard(_appliedStore!)],
    );
  }

  Widget _buildAppliedStoreCard(AppliedStoreData store) {
    final isApproved = _isApprovedStatus(store.status);
    final statusColor = _appliedStatusColor(store.status);

    return InkWell(
      onTap: () => _goToAppliedStoreDetail(store),
      borderRadius: BorderRadius.circular(_cardRadius),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStoreImage(store.profileImage, size: 70, radius: 16),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        store.storeName.isNotEmpty ? store.storeName : '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          store.statusLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.phone.isNotEmpty ? store.phone : '-',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Icon(
                              Icons.location_on_rounded,
                              color: Colors.grey[700],
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store.address.isNotEmpty ? store.address : '-',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[700],
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _unapplying ? null : _confirmUnapply,
                      tooltip: 'ยกเลิกการสมัคร',
                      icon: _unapplying
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.delete_outline_rounded,
                              color: _danger,
                            ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.grey.shade400,
                      size: 16,
                    ),
                  ],
                ),
              ],
            ),
            if (isApproved) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _goToWork,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('เริ่มทำงาน'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 90),
        Icon(Icons.error_outline_rounded, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 14),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18, color: _primary),
          label: const Text(
            'ลองอีกครั้ง',
            style: TextStyle(color: _primary, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 64, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ],
    );
  }

  Widget _buildStoreImage(
    String imageUrl, {
    required double size,
    required double radius,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _storeFallbackIcon(size: size, radius: radius),
            )
          : _storeFallbackIcon(size: size, radius: radius),
    );
  }

  Widget _buildChip({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required String text,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeFallbackIcon({required double size, required double radius}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: Colors.blue[100],
      ),
      child: Icon(Icons.store_rounded, color: _primary, size: size * 0.45),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 12.5,
                  color: color,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}