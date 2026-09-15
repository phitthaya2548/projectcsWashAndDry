import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wash_and_dry/models/res/customer/res_notification_customer.dart';
import 'package:wash_and_dry/screens/customer/orders/customer_order_detail_screen.dart';
import 'package:wash_and_dry/screens/store/store_befororder_detail_screen.dart';
import 'package:wash_and_dry/service/notification_api_service.dart';
import 'package:wash_and_dry/service/notification_service.dart';

class NotificationHistoryScreen extends StatefulWidget {
  final String userId;
  final String userRole;
  final VoidCallback? onUnreadChanged;

  const NotificationHistoryScreen({
    super.key,
    required this.userId,
    required this.userRole,
    this.onUnreadChanged,
  });

  @override
  State<NotificationHistoryScreen> createState() =>
      _NotificationHistoryScreenState();
}

class _NotificationHistoryScreenState
    extends State<NotificationHistoryScreen> {
  List<NotificationModel> _items = [];
  bool _loading = true;
  String? _error;
  bool _hasReadSomething = false;

  static const _accent = Color(0xFFF59E0B);
  static const _bg = Color(0xFFF7F8FA);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF1F2430);
  static const _textSecondary = Color(0xFF7A8194);
  static const _divider = Color(0xFFEDEFF3);

  StreamSubscription<String?>? _orderUpdateSub;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    _load();

    _orderUpdateSub = NotificationService().onOrderUpdate.listen((_) {
      _debounce?.cancel();

      _debounce = Timer(
        const Duration(milliseconds: 400),
        () {
          if (mounted) {
            _load(silent: true);
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _orderUpdateSub?.cancel();
    super.dispose();
  }

  Future<void> _load({
    bool silent = false,
  }) async {
    if (!mounted) return;

    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final result = await NotificationApiService.getHistory(
        userId: widget.userId,
        userRole: widget.userRole,
      );

      if (!mounted) return;

      setState(() {
        _items = result;

        if (!silent) {
          _error = null;
        }
      });
    } catch (e) {
      if (!mounted) return;

      if (!silent) {
        setState(() {
          _error = _friendlyError(e);
        });
      }
    } finally {
      if (mounted && !silent) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();

    if (msg.contains('socket') || msg.contains('network')) {
      return 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาลองใหม่อีกครั้ง';
    }

    if (msg.contains('timeout')) {
      return 'เชื่อมต่อล่าช้าเกินไป กรุณาลองใหม่อีกครั้ง';
    }

    return 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง';
  }

  Future<void> _onTapItem(NotificationModel item) async {
    if (!item.isRead) {
      try {
        await NotificationApiService.markAsRead(item.id);

        _hasReadSomething = true;

        widget.onUnreadChanged?.call();

        await _load(silent: true);
      } catch (e) {
        debugPrint(
          'Mark notification as read error: $e',
        );
      }
    }

    final orderId = item.orderId?.toString();

    if (orderId == null || orderId.isEmpty) {
      return;
    }

    final role = widget.userRole
        .trim()
        .toLowerCase();

    if (role == 'store') {
      await Get.to(
        () => StoreOrderDetailScreen(
          orderId: orderId,
        ),
      );

      return;
    }

    if (role == 'customer') {
      await Get.to(
        () => CustomerOrderDetailScreen(
          orderId: orderId,
        ),
      );

      return;
    }
  }

  Future<void> _markAllAsRead() async {
    final hasUnread = _items.any((item) => !item.isRead);

    if (!hasUnread) {
      Get.snackbar(
        "แจ้งเตือน",
        "อ่านครบทุกรายการแล้ว",
        snackPosition: SnackPosition.TOP,
        backgroundColor: _accent,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 10,
      );
      return;
    }

    try {
      await NotificationApiService.markAllAsRead(
        userId: widget.userId,
        userRole: widget.userRole,
      );

      _hasReadSomething = true;
      widget.onUnreadChanged?.call();

      await _load(silent: true);

      Get.snackbar(
        "สำเร็จ",
        "อ่านการแจ้งเตือนทั้งหมดแล้ว",
        snackPosition: SnackPosition.TOP,
        backgroundColor: const Color(0xFF16A34A),
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 10,
      );
    } catch (e) {
      debugPrint('Mark all as read error: $e');
      Get.snackbar(
        "เกิดข้อผิดพลาด",
        "ไม่สามารถอ่านทั้งหมดได้ กรุณาลองใหม่",
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red[600],
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 10,
      );
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();

    final isToday =
        dt.year == now.year &&
        dt.month == now.month &&
        dt.day == now.day;

    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    if (isToday) {
      return 'วันนี้ $time';
    }

    final yesterday = now.subtract(
      const Duration(days: 1),
    );

    final isYesterday =
        dt.year == yesterday.year &&
        dt.month == yesterday.month &&
        dt.day == yesterday.day;

    if (isYesterday) {
      return 'เมื่อวาน $time';
    }

    return '${dt.day}/${dt.month}/${dt.year} $time';
  }

  String _formatOrderNumber(String rawId) {
    final value = rawId.trim();

    if (value.length <= 8) {
      return value.padLeft(8, '0');
    }

    return value.substring(0, 8);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_hasReadSomething) {
          widget.onUnreadChanged?.call();
        }

        return true;
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          title: const Text(
            'การแจ้งเตือน',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
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
          backgroundColor: _bg,
          surfaceTintColor: _bg,
          foregroundColor: _textPrimary,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 18,
            ),
            onPressed: () {
              if (_hasReadSomething) {
                widget.onUnreadChanged?.call();
              }

              Get.back();
            },
          ),
          actions: [
            if (!_loading && _error == null && _items.isNotEmpty)
              TextButton.icon(
                onPressed: _markAllAsRead,
                icon: const Icon(
                  Icons.done_all_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'อ่านทั้งหมด',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
        body: RefreshIndicator(
          color: _accent,
          onRefresh: () => _load(),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: _accent,
        ),
      );
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(
            height: 120,
          ),
          Icon(
            Icons.wifi_off_rounded,
            size: 52,
            color: Colors.grey.shade300,
          ),
          const SizedBox(
            height: 14,
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
              ),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: _textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(
            height: 18,
          ),
          Center(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: _accent,
                side: const BorderSide(
                  color: _accent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    10,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 10,
                ),
              ),
              onPressed: () => _load(),
              child: const Text(
                'ลองอีกครั้ง',
              ),
            ),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(
            height: 140,
          ),
          Icon(
            Icons.notifications_none_rounded,
            size: 60,
            color: Colors.grey.shade300,
          ),
          const SizedBox(
            height: 14,
          ),
          Center(
            child: Text(
              'ยังไม่มีการแจ้งเตือน',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 15,
              ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
        horizontal: 14,
      ),
      itemCount: _items.length,
      itemBuilder: (
        context,
        index,
      ) {
        final item = _items[index];

        final rawOrderId =
            item.orderId?.toString();

        final orderNumber =
            rawOrderId != null &&
                    rawOrderId.isNotEmpty
                ? _formatOrderNumber(
                    rawOrderId,
                  )
                : null;

        return _NotificationCard(
          item: item,
          orderNumber: orderNumber,
          accent: _accent,
          cardBg: _cardBg,
          textPrimary: _textPrimary,
          textSecondary: _textSecondary,
          divider: _divider,
          formattedDate: _formatDate(
            item.createdAt,
          ),
          onTap: () => _onTapItem(
            item,
          ),
        );
      },
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final String? orderNumber;
  final Color accent;
  final Color cardBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color divider;
  final String formattedDate;
  final VoidCallback onTap;

  const _NotificationCard({
    required this.item,
    required this.orderNumber,
    required this.accent,
    required this.cardBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.divider,
    required this.formattedDate,
    required this.onTap,
  });
  bool get _hasOrder =>
      orderNumber != null &&
      orderNumber!.isNotEmpty;
  @override
  Widget build(BuildContext context) {
    final unread = !item.isRead;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(
          16,
        ),
        border: Border.all(
          color: unread
              ? accent.withOpacity(0.18)
              : divider,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              0.03,
            ),
            blurRadius: 10,
            offset: const Offset(
              0,
              2,
            ),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(
          16,
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(
            16,
          ),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(
              14,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                if (_hasOrder)
                  _buildOrderHeaderRow(),
                if (_hasOrder)
                  const SizedBox(
                    height: 10,
                  ),
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _buildIcon(),
                    const SizedBox(
                      width: 12,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight:
                                        unread
                                            ? FontWeight
                                                .w700
                                            : FontWeight
                                                .w500,
                                    color:
                                        textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow
                                          .ellipsis,
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin:
                                      const EdgeInsets
                                          .only(
                                    left: 6,
                                  ),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        accent,
                                    shape:
                                        BoxShape
                                            .circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(
                            height: 4,
                          ),
                          Text(
                            item.body,
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  textSecondary,
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons
                                    .access_time_rounded,
                                size: 12,
                                color:
                                    textSecondary,
                              ),
                              const SizedBox(
                                width: 3,
                              ),
                              Text(
                                formattedDate,
                                style:
                                    TextStyle(
                                  fontSize:
                                      11.5,
                                  color:
                                      textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_hasOrder)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          left: 4,
                          top: 4,
                        ),
                        child: Icon(
                          Icons
                              .chevron_right_rounded,
                          color: Colors
                              .grey.shade300,
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildOrderHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(
          0xFFF3F4F7,
        ),
        borderRadius: BorderRadius.circular(
          10,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
  '#$orderNumber'.toUpperCase(),
  style: TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    color: textPrimary,
  ),
  maxLines: 1,
  overflow: TextOverflow.ellipsis,
),
          ),
          const SizedBox(
            width: 8,
          ),
          _StatusPill(
            isRead: item.isRead,
            accent: accent,
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: item.isRead
            ? const Color(
                0xFFF3F4F7,
              )
            : accent.withOpacity(
                0.10,
              ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        item.isRead
            ? Icons.notifications_none_rounded
            : Icons.notifications_active_rounded,
        color: item.isRead
            ? Colors.grey.shade400
            : accent,
        size: 19,
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isRead;
  final Color accent;

  const _StatusPill({
    required this.isRead,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isRead
        ? Colors.grey.shade500
        : const Color(
            0xFF16A34A,
          );

    final label =
        isRead ? 'อ่านแล้ว' : 'ใหม่';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(
          0.10,
        ),
        borderRadius: BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}