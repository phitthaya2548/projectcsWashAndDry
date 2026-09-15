import 'dart:async';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/res/customer/store/res_review_store.dart';
import 'package:wash_and_dry/service/session_service.dart';


class StoreReviewScreen extends StatefulWidget {


  const StoreReviewScreen({super.key});

  @override
  State<StoreReviewScreen> createState() => _StoreReviewScreenState();
}

class _StoreReviewScreenState extends State<StoreReviewScreen> {
  String url = '';
  bool isLoading = true;
  String? errorMessage;
  String? storeId;
  StoreReviewsResponse? data;

  int? _selectedRating;

  static const List<String> _thaiMonths = [
    'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
    'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
  ];

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      _selectedRating = null;
    });

    try {
      final session = Session();
      final storeId = await session.getStoreId();
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';

      if (url.isEmpty) {
        throw Exception('ไม่พบ API URL');
      }

      final uri = Uri.parse('$url/order/store/${storeId}/reviews');
      log('GET: $uri');

      final res = await http
          .get(uri, headers: {'Content-Type': 'application/json'})
          .timeout(const Duration(seconds: 10));

      log('Status: ${res.statusCode}');

      if (res.statusCode != 200) {
        throw Exception('เกิดข้อผิดพลาด (${res.statusCode})');
      }

      final parsed = storeReviewsFromJson(res.body);

      if (mounted) {
        setState(() {
          data = parsed;
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
      log('Error loading reviews: $e');
      if (mounted) {
        setState(() {
          errorMessage = e.toString().replaceAll('Exception: ', '');
          isLoading = false;
        });
      }
    }
  }

 
  Map<int, int> _ratingDistribution(List<ReviewItem> reviews) {
    final counts = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final r in reviews) {
      if (counts.containsKey(r.rating)) {
        counts[r.rating] = counts[r.rating]! + 1;
      }
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
          'รีวิวของลูกค้า',
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
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: (data == null || data!.reviews.isEmpty)
                      ? _buildEmpty()
                      : _buildContent(data!),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadReviews,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        const Icon(Icons.reviews_outlined, size: 72, color: Color(0xFFBDBDBD)),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'ยังไม่มีรีวิวสำหรับร้านนี้',
            style: TextStyle(fontSize: 15, color: Color(0xFF757575)),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(StoreReviewsResponse data) {
    final filtered = _selectedRating == null
        ? data.reviews
        : data.reviews.where((r) => r.rating == _selectedRating).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildSummaryCard(data),
        if (_selectedRating != null) _buildFilterBar(),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          _buildFilteredEmpty()
        else
          Container(
            color: Colors.white,
            child: Column(
              children: [
                for (int i = 0; i < filtered.length; i++) ...[
                  _buildReviewTile(filtered[i]),
                  if (i != filtered.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }

  /// แถบแสดงว่ากำลังกรองดาวไหนอยู่ พร้อมปุ่มล้างตัวกรอง
  Widget _buildFilterBar() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Chip(
          label: Text('กำลังกรอง: $_selectedRating ดาว'),
          avatar: const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 18),
          deleteIcon: const Icon(Icons.close, size: 16),
          onDeleted: () => setState(() => _selectedRating = null),
          backgroundColor: const Color(0xFFFFF8E1),
          labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF1E293B)),
        ),
      ),
    );
  }

  Widget _buildFilteredEmpty() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.filter_alt_off_rounded, size: 56, color: Color(0xFFBDBDBD)),
          const SizedBox(height: 12),
          Text(
            'ไม่มีรีวิว $_selectedRating ดาว',
            style: const TextStyle(fontSize: 14, color: Color(0xFF757575)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _selectedRating = null),
            child: const Text('ล้างตัวกรอง'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(StoreReviewsResponse data) {
    final dist = _ratingDistribution(data.reviews);
    final maxCount = dist.values.fold<int>(0, (m, v) => v > m ? v : m);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ซ้าย: ตัวเลขคะแนนเฉลี่ย + ดาว + จำนวนรีวิว
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                _buildStars(data.avgRating, size: 16),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _selectedRating == null
                      ? null
                      : () => setState(() => _selectedRating = null),
                  child: Text(
                    '${data.reviewCount} รีวิว',
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF9E9E9E),
                      decoration: _selectedRating == null
                          ? null
                          : TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ขวา: แถบกระจายคะแนนดาว 5-1
          Expanded(
            flex: 6,
            child: Column(
              children: [
                for (int star = 5; star >= 1; star--)
                  _buildDistributionRow(
                    star,
                    dist[star] ?? 0,
                    maxCount == 0 ? 1 : maxCount,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow(int star, int count, int maxCount) {
    final ratio = count / maxCount;
    final isSelected = _selectedRating == star;
    final isDisabled = count == 0;

    return InkWell(
      onTap: isDisabled
          ? null
          : () => setState(() {
                _selectedRating = isSelected ? null : star;
              }),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF3D6) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Text(
              '$star',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                color: isDisabled ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.star_rounded,
              color: isDisabled ? const Color(0xFFBDBDBD) : const Color(0xFFFFB300),
              size: 12,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDisabled ? const Color(0xFFE5E7EB) : const Color(0xFFFFB300),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 16,
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
                  color: isDisabled ? const Color(0xFFBDBDBD) : const Color(0xFF757575),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewTile(ReviewItem review) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE3F2FD),
                backgroundImage: review.customerProfileImage.isNotEmpty
                    ? NetworkImage(review.customerProfileImage)
                    : null,
                child: review.customerProfileImage.isEmpty
                    ? const Icon(Icons.person, color: Color(0xFF2196F3), size: 20)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerFullname,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _buildStars(review.rating.toDouble(), size: 13),
                        const SizedBox(width: 6),
                        if (review.reviewedAt != null)
                          Text(
                            _formatDate(review.reviewedAt!),
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9E9E9E)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 46),
              child: Text(
                review.comment!,
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.4),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        IconData icon;
        if (rating >= i + 1) {
          icon = Icons.star_rounded;
        } else if (rating > i && rating < i + 1) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }
        return Icon(icon, color: const Color(0xFFFFB300), size: size);
      }),
    );
  }

  String _formatDate(DateTime date) {
    final month = _thaiMonths[date.month - 1];
    return '${date.day} $month ${date.year}';
  }
}