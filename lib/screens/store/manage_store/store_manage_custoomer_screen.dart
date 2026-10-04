import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_getx_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_manage_customer_store.dart';
import 'package:wash_and_dry/screens/store/manage_store/store_history_customer_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';


class ManageCustomersScreen extends StatefulWidget {
  const ManageCustomersScreen({Key? key}) : super(key: key);

  @override
  State<ManageCustomersScreen> createState() => _ManageCustomersScreenState();
}

class _ManageCustomersScreenState extends State<ManageCustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  String url = '';
  String? _storeId;

  bool _isLoading = true;
  String? _errorMessage;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // โหลด config + storeId แล้วยิง API ครั้งแรก
  Future<void> _loadData({String search = ''}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final config = await Configuration.getConfig();
      final session = Session();
      final storeId = await session.getStoreId();

      if (storeId == null) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูลร้านค้า';
          _isLoading = false;
        });
        return;
      }

      url = config['apiEndpoint']?.toString() ?? '';
      _storeId = storeId;

      await _fetchCustomers(search: search);
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
        _isLoading = false;
      });
    }
  }


  Future<void> _fetchCustomers({String search = ''}) async {
    if (url.isEmpty || _storeId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('$url/history/order/customers/$_storeId')
          .replace(queryParameters: search.isNotEmpty ? {'q': search} : null);

      final res = await http.get(uri);
      final body = jsonDecode(res.body) as Map<String, dynamic>;

      final result = StoreCustomersResponse.fromJson(body);

      if (res.statusCode == 200 && result.ok) {
        setState(() {
          _customers = result.data;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result.message ?? 'ไม่สามารถโหลดข้อมูลได้';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เชื่อมต่อ API ไม่สำเร็จ: $e';
        _isLoading = false;
      });
    }
  }


  void _onSearchChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchCustomers(search: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF2E9FFF);

    return Scaffold(
      backgroundColor: Colors.white,
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
  leading: IconButton(
    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
    onPressed: () => Navigator.pop(context),
  ),
  centerTitle: true,
        title: const Text(
          'ข้อมูลผู้ใช้',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          _buildSearchBar(primaryBlue),
          Expanded(child: _buildBody(primaryBlue)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(Color primaryBlue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาผู้ใช้',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () =>
                _fetchCustomers(search: _searchController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Icon(Icons.search, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(Color primaryBlue) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return const Center(child: Text('ไม่พบข้อมูลผู้ใช้'));
    }

    return RefreshIndicator(
      onRefresh: () => _fetchCustomers(search: _searchController.text.trim()),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          return _buildCustomerCard(_customers[index], primaryBlue);
        },
      ),
    );
  }

  Widget _buildCustomerCard(Customer customer, Color primaryBlue) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            backgroundImage: customer.profileImage.isNotEmpty
                ? NetworkImage(customer.profileImage)
                : null,
            child: customer.profileImage.isEmpty
                ? const Icon(Icons.person, color: Colors.grey, size: 32)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(Icons.person, 'ชื่อ ${customer.fullname}'),
                const SizedBox(height: 6),
                _infoRow(Icons.email, customer.email),
                const SizedBox(height: 6),
                _infoRow(Icons.phone, customer.phone),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
onPressed: () {
  Get.to(
    () => CustomerServiceHistoryScreen(customerId: customer.customerId),
  );
},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: primaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('ประวัติการใช้บริการ'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}