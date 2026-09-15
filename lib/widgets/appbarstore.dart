import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/store/req_edit_status_store.dart';
import 'package:wash_and_dry/screens/notification_history_screen.dart';
import 'package:wash_and_dry/service/notification_api_service.dart';
import 'package:wash_and_dry/service/notification_service.dart';
import 'package:wash_and_dry/service/session_service.dart';

final _sharedStatus =
    ValueNotifier<String?>(null);

class StoreAppBar
    extends StatefulWidget
    implements PreferredSizeWidget {
  final String title;
  final String storeId;
  final String? profileImage;

  const StoreAppBar({
    super.key,
    required this.title,
    required this.storeId,
    this.profileImage,
  });

  @override
  Size get preferredSize =>
      const Size.fromHeight(
        80,
      );

  @override
  State<StoreAppBar>
      createState() =>
          _StoreAppBarState();
}

class _StoreAppBarState
    extends State<StoreAppBar> {
  String url = '';

  int _unreadCount = 0;

  StreamSubscription<String?>?
      _orderUpdateSub;

  @override
  void initState() {
    super.initState();

    _init();

    _loadUnreadCount();

    _orderUpdateSub =
        NotificationService()
            .onOrderUpdate
            .listen(
      (_) {
        if (mounted) {
          _loadUnreadCount();
        }
      },
    );
  }

  @override
  void dispose() {
    _orderUpdateSub?.cancel();

    super.dispose();
  }

  Future<void> _init() async {
    final cachedStatus =
        await Session()
            .getStatus();

    if (cachedStatus != null &&
        cachedStatus.isNotEmpty) {
      _sharedStatus.value =
          cachedStatus;
    }

    try {
      final config =
          await Configuration
              .getConfig();

      url = config[
                  'apiEndpoint']
              ?.toString() ??
          '';

      await _fetchStatus();
    } catch (_) {}
  }

  Future<void>
      _loadUnreadCount() async {
    try {
      final count =
          await NotificationApiService
              .getUnreadCount(
        userId:
            widget.storeId,
        userRole: 'store',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _unreadCount =
            count;
      });
    } catch (e) {
      log(
        'load unread count error: $e',
      );
    }
  }

  Future<void>
      _fetchStatus() async {
    if (url.isEmpty) {
      return;
    }

    try {
      final res =
          await http.get(
        Uri.parse(
          '$url/store/profile/status/${widget.storeId}',
        ),
      );

      if (res.statusCode ==
          200) {
        final response =
            storeStatusResponseFromJson(
          res.body,
        );

        if (response.ok &&
            response.data !=
                null) {
          _sharedStatus
                  .value =
              response
                  .data!
                  .status;

          await Session()
              .updateStatus(
            response
                .data!
                .status,
          );
        }
      }
    } catch (e) {
      log(
        'fetch error: $e',
      );
    }
  }

  Future<void> _updateStatus(
    String newStatus,
  ) async {
    if (url.isEmpty) {
      return;
    }

    final previousStatus =
        _sharedStatus.value;

    _sharedStatus.value =
        newStatus;

    try {
      final res =
          await http.put(
        Uri.parse(
          '$url/store/profile/status/${widget.storeId}',
        ),
        headers: {
          'Content-Type':
              'application/json',
        },
        body:
            storeStatusRequestToJson(
          StoreStatusRequest(
            status:
                newStatus,
          ),
        ),
      );

      if (res.statusCode ==
          200) {
        final response =
            storeStatusResponseFromJson(
          res.body,
        );

        if (response.ok) {
          _sharedStatus
                  .value =
              newStatus;

          await Session()
              .updateStatus(
            newStatus,
          );
        } else {
          _sharedStatus
                  .value =
              previousStatus;
        }
      } else {
        _sharedStatus.value =
            previousStatus;
      }
    } catch (e) {
      log(
        'update error: $e',
      );

      _sharedStatus.value =
          previousStatus;
    }
  }

  Future<void>
      _openNotifications() async {
    await Get.to(
      () =>
          NotificationHistoryScreen(
        userId:
            widget.storeId,
        userRole: 'store',
        onUnreadChanged:
            _loadUnreadCount,
      ),
    );

    await _loadUnreadCount();

    NotificationService()
        .notifyOrderUpdate();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      decoration:
          const BoxDecoration(
        gradient:
            LinearGradient(
          begin:
              Alignment.topCenter,
          end: Alignment
              .bottomCenter,
          colors: [
            Color(
              0xFF0593FF,
            ),
            Color(
              0xFF0476D9,
            ),
          ],
        ),
        borderRadius:
            BorderRadius.only(
          bottomLeft:
              Radius.circular(
            28,
          ),
          bottomRight:
              Radius.circular(
            28,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Color(
              0x330476D9,
            ),
            blurRadius: 12,
            offset:
                Offset(
              0,
              4,
            ),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding:
              const EdgeInsets
                  .fromLTRB(
            16,
            10,
            10,
            16,
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape
                          .circle,
                  border:
                      Border.all(
                    color: Colors
                        .white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors
                          .black
                          .withOpacity(
                        0.15,
                      ),
                      blurRadius:
                          6,
                      offset:
                          const Offset(
                        0,
                        2,
                      ),
                    ),
                  ],
                ),
                child:
                    ClipOval(
                  child:
                      _buildProfileImage(),
                ),
              ),
              const SizedBox(
                width: 12,
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      widget.title
                              .isEmpty
                          ? 'ร้านค้า'
                          : widget
                              .title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Colors
                                .white,
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight
                                .bold,
                        letterSpacing:
                            0.3,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    ValueListenableBuilder<
                        String?>(
                      valueListenable:
                          _sharedStatus,
                      builder: (
                        context,
                        status,
                        _,
                      ) {
                        final isLoading =
                            status ==
                                null;

                        return GestureDetector(
                          onTap:
                              isLoading
                                  ? null
                                  : _showStatusSheet,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  8,
                              vertical:
                                  3,
                            ),
                            decoration:
                                BoxDecoration(
                              color: Colors
                                  .white
                                  .withOpacity(
                                0.2,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                20,
                              ),
                            ),
                            child:
                                Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,
                              children: [
                                if (isLoading)
                                  const SizedBox(
                                    width:
                                        7,
                                    height:
                                        7,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth:
                                          1.5,
                                      color:
                                          Colors.white70,
                                    ),
                                  )
                                else
                                  Container(
                                    width:
                                        7,
                                    height:
                                        7,
                                    decoration:
                                        BoxDecoration(
                                      color:
                                          _statusColor(
                                        status,
                                      ),
                                      shape:
                                          BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(
                                  width:
                                      5,
                                ),
                                Flexible(
                                  child:
                                      Text(
                                    isLoading
                                        ? 'กำลังโหลด...'
                                        : _statusText(
                                            status,
                                          ),
                                    maxLines:
                                        1,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Colors.white,
                                      fontSize:
                                          11,
                                      fontWeight:
                                          FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (!isLoading) ...[
                                  const SizedBox(
                                    width:
                                        4,
                                  ),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color:
                                        Colors.white70,
                                    size:
                                        14,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              _buildNotificationButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget
      _buildNotificationButton() {
    return InkWell(
      onTap:
          _openNotifications,
      borderRadius:
          BorderRadius.circular(
        25,
      ),
      child: Stack(
        clipBehavior:
            Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration:
                BoxDecoration(
              color: Colors.white
                  .withOpacity(
                0.20,
              ),
              shape:
                  BoxShape.circle,
              border:
                  Border.all(
                color: Colors.white
                    .withOpacity(
                  0.35,
                ),
                width: 1.5,
              ),
            ),
            child:
                const Icon(
              Icons
                  .notifications_none_rounded,
              color:
                  Colors.white,
              size: 25,
            ),
          ),
          if (_unreadCount >
              0)
            Positioned(
              right: -3,
              top: -3,
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal:
                      5,
                  vertical:
                      2,
                ),
                constraints:
                    const BoxConstraints(
                  minWidth:
                      18,
                  minHeight:
                      18,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      Colors.red,
                  borderRadius:
                      BorderRadius
                          .circular(
                    10,
                  ),
                  border:
                      Border.all(
                    color: Colors
                        .white,
                    width:
                        1.5,
                  ),
                ),
                child:
                    Text(
                  _unreadCount >
                          99
                      ? '99+'
                      : _unreadCount
                          .toString(),
                  textAlign:
                      TextAlign
                          .center,
                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        10,
                    height:
                        1.2,
                    fontWeight:
                        FontWeight
                            .bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget
      _buildProfileImage() {
    final img =
        widget.profileImage;

    if (img != null &&
        img.isNotEmpty) {
      return Image.network(
        img,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (
          _,
          __,
          ___,
        ) =>
            _fallback(),
      );
    }

    return _fallback();
  }

  Widget _fallback() {
    return Image.asset(
      'assets/images/logo.png',
      width: 48,
      height: 48,
      fit: BoxFit.cover,
      errorBuilder: (
        _,
        __,
        ___,
      ) {
        return const Icon(
          Icons.store_rounded,
          color: Colors.white,
          size: 26,
        );
      },
    );
  }

  String _statusText(
    String status,
  ) {
    switch (status) {
      case 'OPEN':
        return 'เปิดร้าน';

      case 'TEMP_CLOSED':
        return 'ปิดชั่วคราว';

      default:
        return status;
    }
  }

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'OPEN':
        return const Color(
          0xFF4CD964,
        );

      case 'TEMP_CLOSED':
        return const Color(
          0xFFFF9500,
        );

      default:
        return const Color(
          0xFFFF3B30,
        );
    }
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor:
          Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top:
              Radius.circular(
            16,
          ),
        ),
      ),
      builder: (_) {
        return ValueListenableBuilder<
            String?>(
          valueListenable:
              _sharedStatus,
          builder: (
            context,
            status,
            _,
          ) {
            return Padding(
              padding:
                  const EdgeInsets
                      .fromLTRB(
                16,
                12,
                16,
                32,
              ),
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  Center(
                    child:
                        Container(
                      width: 36,
                      height: 4,
                      margin:
                          const EdgeInsets
                              .only(
                        bottom:
                            16,
                      ),
                      decoration:
                          BoxDecoration(
                        color: Colors
                            .grey
                            .shade300,
                        borderRadius:
                            BorderRadius
                                .circular(
                          4,
                        ),
                      ),
                    ),
                  ),
                  const Text(
                    'สถานะร้านค้า',
                    style:
                        TextStyle(
                      fontSize:
                          14,
                      fontWeight:
                          FontWeight
                              .w600,
                      color:
                          Color(
                        0xFF64748B,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height: 8,
                  ),
                  _statusOption(
                    value:
                        'OPEN',
                    color:
                        const Color(
                      0xFF4CD964,
                    ),
                    currentStatus:
                        status,
                  ),
                  _statusOption(
                    value:
                        'TEMP_CLOSED',
                    color:
                        const Color(
                      0xFFFF9500,
                    ),
                    currentStatus:
                        status,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusOption({
    required String value,
    required Color color,
    required String?
        currentStatus,
  }) {
    final isActive =
        currentStatus == value;

    return ListTile(
      contentPadding:
          const EdgeInsets
              .symmetric(
        horizontal: 4,
        vertical: 2,
      ),
      leading:
          Container(
        width: 10,
        height: 10,
        decoration:
            BoxDecoration(
          color: color,
          shape:
              BoxShape.circle,
        ),
      ),
      title: Text(
        _statusText(
          value,
        ),
        style: TextStyle(
          fontSize: 15,
          fontWeight:
              isActive
                  ? FontWeight
                      .w600
                  : FontWeight
                      .normal,
          color:
              const Color(
            0xFF1E293B,
          ),
        ),
      ),
      trailing:
          isActive
              ? Icon(
                  Icons
                      .check_rounded,
                  color:
                      color,
                  size:
                      20,
                )
              : null,
      onTap: () {
        Navigator.pop(
          context,
        );

        _updateStatus(
          value,
        );
      },
    );
  }
}