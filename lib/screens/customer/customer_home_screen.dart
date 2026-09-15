import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/customer/req_address_customer.dart';
import 'package:wash_and_dry/models/res/customer/res_store_customer.dart';
import 'package:wash_and_dry/models/res/customer/store/res_review_store.dart';
import 'package:wash_and_dry/screens/customer/customer_address_screen.dart';

import 'package:wash_and_dry/screens/customer/customer_detailstore_screen.dart';
import 'package:wash_and_dry/screens/customer/wallet/customer_topup_screen.dart';
import 'package:wash_and_dry/screens/notification_history_screen.dart';
import 'package:wash_and_dry/service/notification_api_service.dart';
import 'package:wash_and_dry/service/notification_service.dart';
import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/drawercustomer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String url = "";
  String? customerId;
  double walletBalance = 0;
  Future<List<Store>>? _futureStores;
  String searchText = "";
  int selectedFilterIndex = 0;
  Address? defaultAddress;
  double? lat = 0.0, lng = 0.0;
  int _unreadCount =0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  final Map<String, double> _ratingCache = {};
  StreamSubscription<String?>? _orderUpdateSub;

 
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
    _init();
      _orderUpdateSub = NotificationService().onOrderUpdate.listen((_) {
      if (mounted) _loadUnreadCount();
    });
  }
@override
  void dispose() {
    _orderUpdateSub?.cancel();
    super.dispose();
  }
  Future<void> _init() async {
    final config = await Configuration.getConfig();
    url = config['apiEndpoint'];
    customerId = await Session().getCustomerId();
    final addr = await getDefaultAddress();
    setState(() {
      defaultAddress = addr;
      _futureStores = fetchStores();
    });
    _listenWallet();
    _loadUnreadCount();
  }
  Future<void> _loadUnreadCount() async {
  final count = await NotificationApiService.getMyUnreadCount();
  if (mounted) {
    setState(() => _unreadCount = count);
  }
}

  void _listenWallet() {
    if (customerId == null) return;
    FirebaseFirestore.instance
        .collection('customers')
        .doc(customerId)
        .snapshots()
        .listen((doc) {
          if (doc.exists && mounted) {
            setState(
              () => walletBalance = (doc.data()?['wallet_balance'] ?? 0)
                  .toDouble(),
            );
          }
        });
  }

  Future<void> _refreshData() async {
    final addr = await getDefaultAddress();
    setState(() {
      defaultAddress = addr;
      _ratingCache.clear();
      _futureStores = fetchStores(search: searchText);
    });
  }

  Future<Address?> getDefaultAddress() async {
    if (customerId == null) return null;
    final res = await http.get(
      Uri.parse("$url/customer/addresses/active/$customerId"),
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data["data"] == null) return null;
    lat = (data["data"]["latitude"] ?? 0).toDouble();
    lng = (data["data"]["longitude"] ?? 0).toDouble();
    log("lat=$lat, lng=$lng");
    return Address.fromJson(data["data"]);
  }

  Future<List<Store>> fetchStores({String search = ""}) async {
    final uri = Uri.parse("$url/customer/getstores").replace(
      queryParameters: {
        "search": search,
        "lat": lat.toString(),
        "lng": lng.toString(),
      },
    );
    final res = await http.get(uri);
    final json = jsonDecode(res.body);
    return (json["data"] as List).map((item) => Store.fromJson(item)).toList();
  }

  Future<double> _fetchStoreAvgRating(String storeId) async {
    if (_ratingCache.containsKey(storeId)) {
      return _ratingCache[storeId]!;
    }
    try {
      final res = await GetConnect().get('$url/order/store/$storeId/reviews');
      if (res.statusCode == 200 && res.body['data'] != null) {
        final avg = StoreReviewsResponse.fromJson(res.body['data']).avgRating;
        _ratingCache[storeId] = avg;
        return avg;
      }
    } catch (_) {}
    _ratingCache[storeId] = 0.0;
    return 0.0;
  }
Future<List<Store>> _sortByRealRating(List<Store> stores) async {
  final Map<String, double> ratingMap = {};
  await Future.wait(stores.map((s) async {
    ratingMap[s.id] = await _fetchStoreAvgRating(s.id);
  }));

  final sorted = List<Store>.from(stores)
    ..sort((a, b) =>
        (ratingMap[b.id] ?? b.rating).compareTo(ratingMap[a.id] ?? a.rating));
  return sorted;
}
 Stream<int> getQueueStream(String storeId) {
  final storeRef = FirebaseFirestore.instance.doc('stores/$storeId');

  return FirebaseFirestore.instance
      .collection('orders')
      .where('store_id', isEqualTo: storeRef)
      .where('status', whereIn: _pendingStatuses)
      .snapshots()
      .map((snap) => snap.docs.length);
}

  Future<void> refresh() => _refreshData();


  String _statusText(String status) {
    switch (status) {
      case 'OPEN':
        return 'เปิดร้าน';
      case 'TEMP_CLOSED':
        return 'ปิดชั่วคราว';
      default:
        return 'ปิด';
    }
  }


  Color _statusColor(String status) {
    switch (status) {
      case 'OPEN':
        return const Color(0xFF4CD964);
      case 'TEMP_CLOSED':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFFFF3B30);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_futureStores == null) {
      return const Scaffold(
  backgroundColor: Color(0xFFF5F7FA),
  body: Center(
    child: CircularProgressIndicator(
      color: Color(0xFF0593FF),
    ),
  ),
);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      key: _scaffoldKey,   
      drawer: const Drawer(
        child: DrawerCustomerContent(),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF0593FF),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverToBoxAdapter(child: _buildStoreListHeader()),
            _buildStoreList(),
          ],
        ),
      ),
    );
  }


  Widget _buildHeader() {
    final address = defaultAddress?.addressText ?? 'ยังไม่มีที่อยู่หลัก';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _circleIconButton(Icons.menu),
                  const Spacer(),
                  _circleIconButton(Icons.notifications_none_rounded),
                ],
              ),
              const SizedBox(height: 12),

              InkWell(
                onTap: () async {
                  final result = await Get.to(
                    () => CustomerAddressScreen(
                      customerId: customerId.toString(),
                    ),
                  );
                  if (result == true) await _refreshData();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'ตำแหน่งของคุณ',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              address,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF0593FF).withOpacity(0.95),
                            const Color(0xFF0593FF).withOpacity(0.25),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'assets/icons/wallet_white.png',
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ยอดเงินคงเหลือ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${walletBalance.toStringAsFixed(2)} บาท',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Get.to(() => TopupCustomer()),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'เติมเงิน',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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
Widget _circleIconButton(IconData icon) {
  return InkWell(
  onTap: () async {
    if (icon == Icons.menu) {
      _scaffoldKey.currentState?.openDrawer();
    } else {
      final customerId = await Session().getCustomerId();

if (customerId == null || customerId.isEmpty) return;

await Get.to(
  () => NotificationHistoryScreen(
    userId: customerId,
    userRole: 'customer',
  ),
);
      _loadUnreadCount();
    }
  },
    borderRadius: BorderRadius.circular(25),
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        if (icon != Icons.menu && _unreadCount > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );
}
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: TextField(
        decoration: InputDecoration(
          hintText: "ค้นหาร้าน...",
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
        onChanged: (value) {
  searchText = value;
  setState(() {
    _futureStores = fetchStores(search: value); 
  });
},
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['ทั้งหมด', 'ใกล้ฉัน', 'คะแนนสูง'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(filters.length, (i) {
          final active = selectedFilterIndex == i;
          return Padding(
            padding: EdgeInsets.only(right: i < filters.length - 1 ? 8 : 0),
            child: InkWell(
              onTap: () => setState(() => selectedFilterIndex = i),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: active
                      ? const LinearGradient(
                          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
                        )
                      : null,
                  color: active ? null : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active ? Colors.transparent : Colors.grey[300]!,
                  ),
                ),
                child: Text(
                  filters[i],
                  style: TextStyle(
                    color: active ? Colors.white : Colors.grey[700],
                    fontSize: 14,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStoreListHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'ร้านยอดนิยมใกล้คุณ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
         
        ],
      ),
    );
  }

 Widget _buildStoreList() {
  return FutureBuilder<List<Store>>(
    future: _futureStores,
    builder: (context, datastore) {
      if (datastore.connectionState == ConnectionState.waiting) {
        return const SliverToBoxAdapter(
          child: Center(
            child: CircularProgressIndicator(
              backgroundColor: Color(0xFFF5F7FA),
            ),
          ),
        );
      }

      if (!datastore.hasData || datastore.data!.isEmpty) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Column(
              children: [
                Icon(Icons.store_outlined, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  "ไม่พบร้าน",
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      }

      List<Store> stores = List.from(datastore.data!);

      if (selectedFilterIndex == 1) {
        stores.sort((a, b) => a.distance.compareTo(b.distance));
        return _storeListSliver(stores);
      }

      if (selectedFilterIndex == 2) {

        return FutureBuilder<List<Store>>(
          future: _sortByRealRating(stores),
          builder: (context, sortedSnap) {
            if (!sortedSnap.hasData) {
              return const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF0593FF),
                    ),
                  ),
                ),
              );
            }
            return _storeListSliver(sortedSnap.data!);
          },
        );
      }

      return _storeListSliver(stores);
    },
  );
}

Widget _storeListSliver(List<Store> stores) {
  return SliverPadding(
    padding: const EdgeInsets.only(top: 4, bottom: 20),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, i) => _buildStoreCard(stores[i]),
        childCount: stores.length,
      ),
    ),
  );
}



  Widget _buildStoreCard(Store store) {
    return InkWell(
      onTap: () {
        log("Tapped: ${store.name} (${store.id})");
        Get.to(() => CustomerStoreDetailScreen(storeId: store.id));
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [

            SizedBox(
              width: 70,
              height: 70,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      store.image,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.blue[100],
                        ),
                        child: const Icon(
                          Icons.store_rounded,
                          color: Color(0xFF0593FF),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(store.status),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Text(
                        _statusText(store.status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),


            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      StreamBuilder<int>(
                        stream: getQueueStream(store.id),
                        builder: (context, snap) {
                          final count = snap.data ?? 0;
                          final loading =
                              snap.connectionState == ConnectionState.waiting;
                          final hasQueue = count > 0;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: hasQueue
                                  ? const Color(0xFFF1F5F9)
                                  : const Color(0xFF0593FF),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_alt_rounded,
                                  size: 14,
                                  color: hasQueue
                                      ? const Color(0xFF0593FF)
                                      : Colors.white,
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
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: hasQueue
                                              ? const Color(0xFF0593FF)
                                              : Colors.white,
                                        ),
                                      ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Colors.orange,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      FutureBuilder<double>(
                        future: _fetchStoreAvgRating(store.id),
                        builder: (context, snap) {
                          final rating = snap.data ?? store.rating;
                          return Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.location_on_rounded,
                        color: Colors.blue[700],
                        size: 14,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        "${store.distance} km",
                        style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        store.opening,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}