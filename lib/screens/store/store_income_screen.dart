import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' hide log;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_profile_store.dart';
import 'package:wash_and_dry/models/res/customer/store/res_report_store.dart';

import 'package:wash_and_dry/service/session_service.dart';
import 'package:wash_and_dry/widgets/appbarstore.dart';

const Color kPrimaryBlue = Color(0xFF2E9FE8);
const Color kPrimaryBlueDark = Color(0xFF1C7FC4);
const Color kRevenueGreen = Color(0xFF2ECC71);
const Color kRevenueGreenDark = Color(0xFF1FA85C);
const Color kCardBg = Colors.white;
const Color kScreenBg = Color(0xFFF4F6F8);

class StoreIncomeScreen extends StatefulWidget {
  const StoreIncomeScreen({super.key});

  @override
  State<StoreIncomeScreen> createState() => _StoreIncomeScreenState();
}

class _StoreIncomeScreenState extends State<StoreIncomeScreen> {
  String url = '';
  StoreData? storeData;
  bool isLoading = true;
  String? errorMessage;
  String? storeId;
  double walletBalance = 0.0;
  String selectedRange = 'day';
  RevenueReportResponse? reportData;
  bool isLoadingReport = false;
  String? reportError;

  int? selectedChartIndex;

  final List<_RangeOption> _rangeOptions = const [
    _RangeOption(value: 'day', label: 'วัน'),
    _RangeOption(value: 'week', label: 'สัปดาห์'),
    _RangeOption(value: 'month', label: 'เดือน'),
    _RangeOption(value: 'year', label: 'ปี'),
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      log('API URL: $url');

      final session = Session();
      storeId = await session.getStoreId();
      log('Store ID: $storeId');

      if (url.isEmpty) throw Exception('ไม่พบ API URL');
      if (storeId == null || storeId!.isEmpty) {
        throw Exception('ไม่พบ Store ID - กรุณาเข้าสู่ระบบใหม่');
      }

      await _getStoreProfile();
      await _getWalletBalance();
      await _getRevenueReport(selectedRange);
    } catch (e) {
      log('Error: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getWalletBalance() async {
    if (storeId == null || storeId!.isEmpty || url.isEmpty) return;

    try {
      final uri = Uri.parse(
        '$url/report/store/walletbalance/$storeId',
      );

      log('Wallet URL: $uri');

      final res = await http
          .get(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      log('Wallet status: ${res.statusCode}');
      log('Wallet response: ${res.body}');

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final body = jsonDecode(res.body) as Map<String, dynamic>;

      if (body['ok'] != true) {
        throw Exception(
          body['message'] ?? 'ดึงข้อมูล Wallet ไม่สำเร็จ',
        );
      }

      final balance =
          (body['wallet_balance'] as num?)?.toDouble() ?? 0.0;

      if (!mounted) return;

      setState(() {
        walletBalance = balance;
      });
    } on TimeoutException {
      log('Wallet Error: เซิร์ฟเวอร์ช้า');
    } catch (e) {
      log('Wallet Error: $e');
    }
  }

  Future<void> _getStoreProfile() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final uri = Uri.parse('$url/store/profile/$storeId');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');

      final body = json.decode(res.body);
      if (body['ok'] != true) throw Exception(body['message'] ?? 'ดึงข้อมูลไม่สำเร็จ');

      final storeJson = body['data'];
      if (storeJson == null) throw Exception('ไม่พบข้อมูลร้านค้า');

      if (mounted) {
        setState(() {
          storeData = StoreData.fromJson(storeJson);
          isLoading = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          errorMessage = 'เซิร์ฟเวอร์ช้า';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          isLoading = false;
        });
      }
    }
  }

  Future<void> _getRevenueReport(String range) async {
    if (!mounted || storeId == null || url.isEmpty) return;
    setState(() {
      isLoadingReport = true;
      reportError = null;
      selectedChartIndex = null;
    });
    try {
      final uri = Uri.parse('$url/report/store/revenue/$storeId?range=$range');
      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');

      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) throw Exception(body['message'] ?? 'ดึงรายงานไม่สำเร็จ');

      if (mounted) {
        setState(() {
          reportData = RevenueReportResponse.fromJson(body);
          isLoadingReport = false;
        });
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          reportError = 'เซิร์ฟเวอร์ช้า';
          isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          reportError = e.toString().replaceAll('Exception: ', '');
          isLoadingReport = false;
        });
      }
    }
  }

  void _onRangeSelected(String range) {
    if (range == selectedRange) return;
    setState(() => selectedRange = range);
    _getRevenueReport(range);
  }

  void _onBarTap(int index) {
    setState(() {
      selectedChartIndex = selectedChartIndex == index ? null : index;
    });
  }

  String _formatNumber(num value) {
    final isNegative = value < 0;
    final intPart = value.abs().round().toString();
    final buffer = StringBuffer();

    for (int i = 0; i < intPart.length; i++) {
      final posFromEnd = intPart.length - i;
      buffer.write(intPart[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return (isNegative ? '-' : '') + buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kScreenBg,
      appBar: storeData == null
          ? null
          : PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: StoreAppBar(
                title: storeData?.storeName ?? '',
                profileImage: storeData?.profileImage,
                storeId: storeData?.storeId ?? '',
              ),
            ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กำลังโหลดข้อมูลร้าน...'),
                ],
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(errorMessage!, style: const TextStyle(fontSize: 16), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _loadData,
                          icon: const Icon(Icons.refresh),
                          label: const Text('ลองใหม่'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await Future.wait([
                      _getWalletBalance(),
                      _getRevenueReport(selectedRange),
                    ]);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSummaryCard(),
                        const SizedBox(height: 16),
                        _buildRangeTabs(),
                        const SizedBox(height: 16),
                        _buildChartCard(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
    );
  }

 // ---------- การ์ดสรุปรายได้ ----------
  Widget _buildSummaryCard() {
    final chart = reportData?.chart ?? [];
    final hasSelection = selectedChartIndex != null && selectedChartIndex! < chart.length;
    final selectedItem = hasSelection ? chart[selectedChartIndex!] : null;

    final displayRevenue = selectedItem?.revenue ?? (reportData?.summary.totalRevenue ?? 0);
    final displayOrderCount = selectedItem?.orderCount ?? (reportData?.summary.orderCount ?? 0);
    final displayLabel = selectedItem?.label ?? 'รายได้รวม';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  displayLabel,
                  key: ValueKey(displayLabel),
                  style: const TextStyle(fontSize: 13, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
              ),
              if (isLoadingReport)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.black38),
                )
              else if (hasSelection)
                GestureDetector(
                  onTap: () => setState(() => selectedChartIndex = null),
                  child: const Text(
                    'ดูยอดรวม',
                    style: TextStyle(
                      fontSize: 12,
                      color: kPrimaryBlueDark,
                      fontWeight: FontWeight.w500,
                      decoration: TextDecoration.underline,
                      decorationColor: kPrimaryBlueDark,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: Row(
              key: ValueKey('$displayRevenue-$displayLabel'),
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  _formatNumber(displayRevenue),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text('บาท', style: TextStyle(fontSize: 14, color: Colors.black38)),
                ),
              ],
            ),
          ),
          // เผื่อคุณมีข้อมูลเทียบช่วงก่อนหน้า ใส่แถบเปอร์เซ็นต์เปลี่ยนแปลงตรงนี้ได้
          // Row(children: [Icon(Icons.trending_up, size:14, color: kRevenueGreen), ...])
          const SizedBox(height: 18),
          Divider(height: 1, thickness: 0.5, color: Colors.black.withOpacity(0.08)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatRow(
                  icon: Icons.receipt_long_rounded,
                  label: 'ออเดอร์',
                  value: '$displayOrderCount',
                ),
              ),
              Container(
                width: 1,
                height: 32,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: Colors.black.withOpacity(0.08),
              ),
              Expanded(
                child: _buildStatRow(
                  icon: Icons.account_balance_wallet_rounded,
                  label: 'คงเหลือ Wallet',
                  value: '${_formatNumber(walletBalance)} บาท',
                ),
              ),
            ],
          ),
          if (reportError != null) ...[
            const SizedBox(height: 12),
            Text(
              reportError!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.black38)),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildRangeTabs() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: _rangeOptions.map((option) {
          final isSelected = option.value == selectedRange;
          return Expanded(
            child: GestureDetector(
              onTap: () => _onRangeSelected(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kPrimaryBlue.withOpacity(0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black54,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

  // ---------- การ์ดกราฟรายได้ ----------
  Widget _buildChartCard() {
    final chart = reportData?.chart ?? [];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'กราฟรายได้',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              const Icon(Icons.bar_chart_rounded, color: kPrimaryBlue),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            selectedChartIndex == null ? 'แตะแท่งกราฟเพื่อดูรายละเอียดด้านบน' : 'แตะซ้ำเพื่อยกเลิกการเลือก',
            style: const TextStyle(fontSize: 11, color: Colors.black38),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: chart.isEmpty
                ? Center(
                    child: Text(
                      isLoadingReport ? 'กำลังโหลด...' : 'ไม่มีข้อมูล',
                      style: const TextStyle(color: Colors.black38),
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      const minBarWidth = 46.0;
                      final evenWidth = constraints.maxWidth / chart.length;
                      final needsScroll = evenWidth < minBarWidth;
                      final barWidth = needsScroll ? minBarWidth : evenWidth;

                      final chartWidget = _RevenueBarChart(
                        chart: chart,
                        formatNumber: _formatNumber,
                        barWidth: barWidth,
                        selectedIndex: selectedChartIndex,
                        onBarTap: _onBarTap,
                      );

                      if (!needsScroll) return chartWidget;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: barWidth * chart.length,
                          child: chartWidget,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _RangeOption {
  final String value;
  final String label;
  const _RangeOption({required this.value, required this.label});
}

class _RevenueBarChart extends StatelessWidget {
  final List<RevenueChartItem> chart;
  final String Function(num) formatNumber;
  final double barWidth;
  final int? selectedIndex;
  final ValueChanged<int> onBarTap;

  const _RevenueBarChart({
    required this.chart,
    required this.formatNumber,
    required this.barWidth,
    required this.selectedIndex,
    required this.onBarTap,
  });

  @override
  Widget build(BuildContext context) {
    final maxRevenue = chart.map((e) => e.revenue).fold<num>(0, max);
    final safeMax = maxRevenue <= 0 ? 1 : maxRevenue;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(chart.length, (index) {
        final item = chart[index];
        final heightRatio = item.revenue <= 0 ? 0.02 : (item.revenue / safeMax);
        final isSelected = selectedIndex == index;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onBarTap(index),
          child: SizedBox(
            width: barWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.revenue > 0 ? formatNumber(item.revenue) : '-',
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? kRevenueGreenDark : Colors.black45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: (110.0 * heightRatio).clamp(4.0, 110.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isSelected
                              ? [kRevenueGreen, kRevenueGreenDark]
                              : [kPrimaryBlue.withOpacity(0.55), kPrimaryBlue.withOpacity(0.35)],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: kRevenueGreen.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected ? kRevenueGreenDark : Colors.black54,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}