import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wash_and_dry/config/config.dart';

import 'package:wash_and_dry/models/res/customer/res_wallet_history_customer.dart';
import 'package:wash_and_dry/screens/customer/wallet/customer_topup_screen.dart';
import 'package:wash_and_dry/service/session_service.dart';

class WalletTransaction {
  final String id;
  final String type;
  final double amount;
  final String label;
  final String subtitle;
  final DateTime? datetime;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.label,
    required this.subtitle,
    this.datetime,
  });

  bool get isTopup => type == 'topup';
}

class _ListEntry {
  final String? header;
  final WalletTransaction? transaction;

  const _ListEntry.header(this.header) : transaction = null;
  const _ListEntry.item(this.transaction) : header = null;

  bool get isHeader => header != null;
}

class _WalletDateGrouper {
  static const List<String> _thaiMonths = [
    '',
    'มกราคม',
    'กุมภาพันธ์',
    'มีนาคม',
    'เมษายน',
    'พฤษภาคม',
    'มิถุนายน',
    'กรกฎาคม',
    'สิงหาคม',
    'กันยายน',
    'ตุลาคม',
    'พฤศจิกายน',
    'ธันวาคม',
  ];

  static String headerFor(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return 'วันนี้';
    if (diff == 1) return 'เมื่อวาน';
    return '${dt.day} ${_thaiMonths[dt.month]} ${dt.year + 543}';
  }

  static String formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  static List<_ListEntry> group(List<WalletTransaction> transactions) {
    final entries = <_ListEntry>[];
    String? lastHeader;

    for (final tx in transactions) {
      final header = tx.datetime != null
          ? headerFor(tx.datetime!)
          : 'ไม่ทราบวันที่';
      if (header != lastHeader) {
        entries.add(_ListEntry.header(header));
        lastHeader = header;
      }
      entries.add(_ListEntry.item(tx));
    }
    return entries;
  }
}

class WalletCustomerScreen extends StatefulWidget {
  const WalletCustomerScreen({super.key});

  @override
  State<WalletCustomerScreen> createState() => _WalletCustomerScreenState();
}

class _WalletCustomerScreenState extends State<WalletCustomerScreen> {
  final _session = Session();
  final _firestore = FirebaseFirestore.instance;

  double _balance = 0;
  List<WalletTransaction> _transactions = [];
  List<WalletTransaction> _topups = [];
  List<WalletTransaction> _payments = [];
  bool _loading = true;
  String? _customerId;
  String _apiUrl = '';

  static const Map<String, String> _serviceLabels = {
    'wash': 'ซักอย่างเดียว',
    'dry': 'อบอย่างเดียว',
    'wash_dry': 'ซักและอบ',
  };

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await Configuration.getConfig();
      _apiUrl = config['apiEndpoint']?.toString() ?? '';
    } catch (_) {
      _apiUrl = '';
    }
  }

  Future<void> _loadWallet() async {
    _customerId = await _session.getCustomerId();
    if (_customerId == null || _customerId!.isEmpty) {
      _showSnackbar("ไม่พบข้อมูล Customer ID");
      setState(() => _loading = false);
      return;
    }

    await _loadConfig();
    if (_apiUrl.isEmpty) {
      _showSnackbar("ไม่พบการตั้งค่า API");
      setState(() => _loading = false);
      return;
    }

    _listenBalance();
    await _fetchAllHistory();
  }

  void _listenBalance() {
    _firestore.collection('customers').doc(_customerId).snapshots().listen((
      doc,
    ) {
      if (doc.exists && mounted) {
        setState(() {
          _balance = (doc.data()?['wallet_balance'] ?? 0).toDouble();
        });
      }
    }, onError: (e) => _showSnackbar("เกิดข้อผิดพลาด: $e"));
  }

  Future<void> _fetchAllHistory() async {
    await Future.wait([_fetchTopupHistory(), _fetchPaymentHistory()]);
    _mergeAndUpdate();
  }

  Future<void> _fetchTopupHistory() async {
    try {
      final uri = Uri.parse("$_apiUrl/wallet/history/topup/$_customerId");
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        log('topup history http error: ${res.statusCode}');
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final parsed = HistoryResponse<TopupHistoryItem>.fromJson(
        body,
        (e) => TopupHistoryItem.fromJson(e),
      );
      if (!parsed.ok) {
        log('topup history not ok: ${parsed.message}');
        return;
      }

      _topups = parsed.data
          .map(
            (item) => WalletTransaction(
              id: item.topupId,
              type: 'topup',
              amount: item.amount.toDouble(),
              label: 'เติมเงิน',
              subtitle: 'บริการเติมเงิน',
              datetime: item.datetime,
            ),
          )
          .toList();
    } catch (e) {
      log('topup error: $e');
    }
  }

  Future<void> _fetchPaymentHistory() async {
    try {
      final uri = Uri.parse("$_apiUrl/wallet/history/paid_orders/$_customerId");
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        log('payment history http error: ${res.statusCode}');
        return;
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final parsed = HistoryResponse<PaidOrderHistoryItem>.fromJson(
        body,
        (e) => PaidOrderHistoryItem.fromJson(e),
      );
      if (!parsed.ok) {
        log('payment history not ok: ${parsed.message}');
        return;
      }

      _payments = parsed.data
          .map(
            (item) => WalletTransaction(
              id: item.orderId,
              type: 'payment',
              amount: item.totalAmount.toDouble(),
              label: 'ชำระค่าบริการ',
              subtitle: _serviceLabels[item.serviceType] ?? item.serviceType,
              datetime: item.datetime,
            ),
          )
          .toList();
    } catch (e) {
      log('payment error: $e');
    }
  }

  Future<void> _refreshHistory() async {
    if (_customerId == null || _apiUrl.isEmpty) return;
    setState(() => _loading = true);
    await _fetchAllHistory();
  }

  void _mergeAndUpdate() {
    final all = [..._topups, ..._payments]
      ..sort((a, b) {
        if (a.datetime == null) return 1;
        if (b.datetime == null) return -1;
        return b.datetime!.compareTo(a.datetime!);
      });
    if (!mounted) return;
    setState(() {
      _transactions = all;
      _loading = false;
    });
  }

  void _showSnackbar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> _goToTopup() async {
    final result = await Get.to(() => TopupCustomer());
    if (result == true) {
      _refreshHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      backgroundColor: const Color(0xFFF5F7FB),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final bool showBack = Get.arguments?["fromGet"] == true;
    return AppBar(
      flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
            ),
          ),
        ),
      title: const Text(
        "กระเป๋าเงิน",
        style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
      ),
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () => Get.back(),
            )
          : null,
      iconTheme: const IconThemeData(color: Colors.white),
      centerTitle: true,
      elevation: 0,
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        const SizedBox(height: 16),
        _BalanceCard(balance: _balance, onTopupPressed: _goToTopup),
        _buildHistoryHeader(),
        const SizedBox(height: 12),
        _HistoryList(transactions: _transactions),
      ],
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            "รายการล่าสุด",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[600]),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final VoidCallback onTopupPressed;

  const _BalanceCard({required this.balance, required this.onTopupPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
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
            color: const Color(0xFF0593FF).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
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
                  const Color.fromARGB(255, 34, 158, 253).withOpacity(0.95),
                  const Color.fromARGB(255, 210, 236, 255).withOpacity(0.25),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Image.asset(
              'assets/icons/wallet_white.png',
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "ยอดเงินคงเหลือ",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  "${balance.toStringAsFixed(0)} บาท",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTopupPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0593FF),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              "เติมเงิน",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<WalletTransaction> transactions;

  const _HistoryList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Expanded(
        child: Center(
          child: Text("ไม่มีรายการ", style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final entries = _WalletDateGrouper.group(transactions);

    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          if (entry.isHeader) {
            return _DateHeader(text: entry.header!, isFirst: index == 0);
          }
          final tx = entry.transaction!;
          return _TransactionCard(
            type: tx.label,
            subtitle: tx.subtitle,
            time: tx.datetime != null
                ? _WalletDateGrouper.formatTime(tx.datetime!)
                : '-',
            amount: tx.amount,
            isTopup: tx.isTopup,
          );
        },
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  final String text;
  final bool isFirst;

  const _DateHeader({required this.text, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: isFirst ? 0 : 16, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final String type;
  final String subtitle;
  final String time;
  final double amount;
  final bool isTopup;

  const _TransactionCard({
    required this.type,
    required this.subtitle,
    required this.time,
    required this.amount,
    required this.isTopup,
  });

  @override
  Widget build(BuildContext context) {
    final color = isTopup ? const Color(0xFF22C55E) : const Color(0xFFEF4444);
    final sign = isTopup ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6E6E6)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                Text(
                  time,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 46,
                height: 46,
                child: Center(
                  child: Image.asset(
                    isTopup
                        ? "assets/icons/topup.png"
                        : "assets/icons/cut_money.png",
                    width: 36,
                    height: 36,
                    color: isTopup ? null : color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "$sign${amount.toStringAsFixed(0)} ฿",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
