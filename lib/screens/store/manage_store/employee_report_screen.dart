import 'dart:convert';
import 'dart:developer';

import 'package:calendar_date_picker2/calendar_date_picker2.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_employees_report_store.dart';
import 'package:wash_and_dry/service/session_service.dart';

class EmployeeReportScreen extends StatefulWidget {
  const EmployeeReportScreen({super.key});

  @override
  State<EmployeeReportScreen> createState() => _EmployeeReportScreenState();
}

class _EmployeeReportScreenState extends State<EmployeeReportScreen> {
  static const _primary = Color(0xFF0593FF);
  static const _primaryDark = Color(0xFF0476D9);
  static const _dark = Color(0xFF1A1A2E);
  static const _bg = Color(0xFFF2F4F7);
  static const _border = Color(0xFFE2E8F0);

  String url = '';
  String storeId = '';
  bool isLoading = true;
  String reportType = 'day';
  DateTime selectedDay = DateTime.now();
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  EmployeeReportResponse? report;

  static const _thMonths = [
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

  static const _thShortMonths = [
    '',
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final config = await Configuration.getConfig();
      final session = Session();
      final id = await session.getStoreId();

      if (id == null) return;

      url = config['apiEndpoint']?.toString() ?? '';
      storeId = id;

      await _loadReport();
    } catch (e) {
      log('Load report error: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _loadReport() async {
    if (storeId.isEmpty) return;

    if (mounted) {
      setState(() => isLoading = true);
    }

    try {
      final selected = reportType == 'day' ? selectedDay : selectedMonth;

      final query = <String, String>{
        'type': reportType,
        'month': selected.month.toString(),
        'year': selected.year.toString(),
      };

      if (reportType == 'day') {
        query['day'] = selected.day.toString();
      }

      final uri = Uri.parse(
        '$url/employees/report/store/$storeId',
      ).replace(queryParameters: query);

      final response = await http.get(uri);

      log('Report URL: $uri');
      log('Report response: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (mounted) {
          setState(() {
            report = EmployeeReportResponse.fromJson(data);
          });
        }
      } else {
        String message = 'ไม่สามารถโหลดรายงานได้';

        try {
          final data = json.decode(response.body);
          if (data is Map<String, dynamic> && data['message'] != null) {
            message = data['message'].toString();
          }
        } catch (_) {}

        _showError(message);
      }
    } catch (e) {
      log('Report error: $e');
      _showError('ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _displayDate(DateTime date) {
    return '${date.day} ${_thMonths[date.month]} ${date.year + 543}';
  }

  String _displayMonth(DateTime date) {
    return '${_thMonths[date.month]} ${date.year + 543}';
  }

  Future<void> _selectDate() async {
    if (reportType == 'day') {
      await _selectDay();
    } else {
      await _selectMonth();
    }
  }

  Future<void> _selectDay() async {
    final result = await showCalendarDatePicker2Dialog(
      context: context,
      dialogSize: const Size(350, 430),
      value: [selectedDay],
      borderRadius: BorderRadius.circular(24),
      dialogBackgroundColor: Colors.white,
      barrierColor: Colors.black.withOpacity(0.35),
      config: CalendarDatePicker2WithActionButtonsConfig(
        calendarType: CalendarDatePicker2Type.single,
        firstDate: DateTime(2024, 1, 1),
        lastDate: DateTime(2030, 12, 31),
        currentDate: DateTime.now(),
        calendarViewMode: CalendarDatePicker2Mode.day,
        firstDayOfWeek: 0,
        weekdayLabels: const ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'],
        centerAlignModePicker: true,
        selectedDayHighlightColor: _primary,
        dayBorderRadius: BorderRadius.circular(10),
        monthBorderRadius: BorderRadius.circular(10),
        yearBorderRadius: BorderRadius.circular(10),
        controlsTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _dark,
        ),
        weekdayLabelTextStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF94A3B8),
        ),
        dayTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _dark,
        ),
        selectedDayTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        todayTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
        monthTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _dark,
        ),
        selectedMonthTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        yearTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: _dark,
        ),
        selectedYearTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        modePickerTextHandler: ({required monthDate, isMonthPicker}) {
          if (isMonthPicker == true) {
            return _thMonths[monthDate.month];
          }
          return '${monthDate.year + 543}';
        },
        cancelButton: const Text(
          'ยกเลิก',
          style: TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        okButton: const Text(
          'ตกลง',
          style: TextStyle(
            color: _primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        closeDialogOnCancelTapped: true,
        closeDialogOnOkTapped: true,
      ),
    );

    if (result == null || result.isEmpty || result.first == null) return;

    final picked = result.first!;

    if (!mounted) return;

    setState(() {
      selectedDay = DateTime(picked.year, picked.month, picked.day);
    });

    await _loadReport();
  }

  Future<void> _selectMonth() async {
    var tempYear = selectedMonth.year;
    var tempMonth = selectedMonth.month;

    final picked = await showDialog<DateTime>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            color: _primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'เลือกเดือน',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: _dark,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.date_range_rounded,
                            size: 19,
                            color: _primary,
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'ปี',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: tempYear,
                              borderRadius: BorderRadius.circular(14),
                              icon: const Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: _primary,
                              ),
                              style: const TextStyle(
                                fontSize: 15,
                                color: _dark,
                                fontWeight: FontWeight.w700,
                              ),
                              items: List.generate(
                                7,
                                (index) {
                                  final year = 2024 + index;
                                  return DropdownMenuItem<int>(
                                    value: year,
                                    child: Text('${year + 543}'),
                                  );
                                },
                              ),
                              onChanged: (value) {
                                if (value == null) return;
                                setDialogState(() {
                                  tempYear = value;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: 12,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.7,
                      ),
                      itemBuilder: (context, index) {
                        final month = index + 1;
                        final selected = tempMonth == month;

                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              tempMonth = month;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? _primary
                                  : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected ? _primary : _border,
                              ),
                            ),
                            child: Text(
                              _thShortMonths[month],
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: selected ? Colors.white : _dark,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF64748B),
                              side: const BorderSide(color: _border),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ยกเลิก',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                dialogContext,
                                DateTime(tempYear, tempMonth, 1),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'ตกลง',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      selectedMonth = DateTime(picked.year, picked.month, 1);
    });

    await _loadReport();
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _dark,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0593FF),
                Color(0xFF0476D9),
              ],
            ),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
            size: 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'รายงานการทำงาน',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _primary),
                  )
                : RefreshIndicator(
                    color: _primary,
                    onRefresh: _loadReport,
                    child: _buildReport(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _typeButton(
                    title: 'เลือกวัน',
                    value: 'day',
                    icon: Icons.calendar_today_rounded,
                  ),
                ),
                Expanded(
                  child: _typeButton(
                    title: 'เลือกเดือน',
                    value: 'month',
                    icon: Icons.calendar_month_rounded,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _selectDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _border),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF4FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      reportType == 'day'
                          ? Icons.event_rounded
                          : Icons.calendar_month_rounded,
                      size: 19,
                      color: _primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reportType == 'day'
                              ? 'วันที่ที่เลือก'
                              : 'เดือนที่เลือก',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reportType == 'day'
                              ? _displayDate(selectedDay)
                              : _displayMonth(selectedMonth),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeButton({
    required String title,
    required String value,
    required IconData icon,
  }) {
    final selected = reportType == value;

    return GestureDetector(
      onTap: () async {
        if (reportType == value) return;

        setState(() {
          reportType = value;
        });

        await _loadReport();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? _primary : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? _primary : const Color(0xFF888888),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport() {
    if (report == null) {
      return ListView(
        children: const [
          SizedBox(height: 180),
          Center(
            child: Text(
              'ไม่พบข้อมูล',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard(),
        const SizedBox(height: 22),
        _sectionTitle(title: 'Rider', count: report!.riders.length),
        const SizedBox(height: 10),
        if (report!.riders.isEmpty)
          _emptyCard('ไม่มีข้อมูล Rider')
        else
          ...report!.riders.map(_riderCard),
        const SizedBox(height: 24),
        _sectionTitle(title: 'พนักงานซักอบ', count: report!.staffs.length),
        const SizedBox(height: 10),
        if (report!.staffs.isEmpty)
          _emptyCard('ไม่มีข้อมูลพนักงานซักอบ')
        else
          ...report!.staffs.map(_staffCard),
      ],
    );
  }

  Widget _summaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              color: _primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'จำนวนออเดอร์',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 2),
                Text(
                  '${report!.totalOrders} ออเดอร์',
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                    color: _dark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _riderCard(RiderReport rider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _profileImage(
                imageUrl: rider.profileImage,
                name: rider.fullname,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rider.fullname,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF222222),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Rider',
                      style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                    ),
                  ],
                ),
              ),
              Text(
                '${rider.totalJobs} งาน',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _jobItem(title: 'รับผ้า', value: rider.pickupJobs)),
              Container(width: 1, height: 32, color: const Color(0xFFE5E5E5)),
              Expanded(child: _jobItem(title: 'ส่งผ้า', value: rider.deliveryJobs)),
              Container(width: 1, height: 32, color: const Color(0xFFE5E5E5)),
              Expanded(child: _jobItem(title: 'รวม', value: rider.totalJobs)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _staffCard(StaffReport staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Row(
        children: [
          _profileImage(
            imageUrl: staff.profileImage,
            name: staff.fullname,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.fullname,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF222222),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                const Text(
                  'พนักงานซักอบ',
                  style: TextStyle(fontSize: 12, color: Color(0xFF777777)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'จำนวนงาน',
                style: TextStyle(fontSize: 11, color: Color(0xFF888888)),
              ),
              const SizedBox(height: 2),
              Text(
                '${staff.totalJobs} งาน',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _profileImage({
    required String? imageUrl,
    required String name,
  }) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return CircleAvatar(
      radius: 24,
      backgroundColor: const Color(0xFFEAF4FF),
      backgroundImage: hasImage ? NetworkImage(imageUrl) : null,
      child: hasImage
          ? null
          : Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: _primary,
              ),
            ),
    );
  }

  Widget _jobItem({
    required String title,
    required int value,
  }) {
    return Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF222222),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          title,
          style: const TextStyle(fontSize: 11, color: Color(0xFF777777)),
        ),
      ],
    );
  }

  Widget _sectionTitle({
    required String title,
    required int count,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF222222),
            ),
          ),
        ),
        Text(
          '$count คน',
          style: const TextStyle(fontSize: 12, color: Color(0xFF777777)),
        ),
      ],
    );
  }

  Widget _emptyCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
      ),
    );
  }
}