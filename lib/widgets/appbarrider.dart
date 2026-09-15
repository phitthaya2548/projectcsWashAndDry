import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:wash_and_dry/config/config.dart';
import 'package:wash_and_dry/models/req/rider/req_edit_status_rider.dart';
import 'package:wash_and_dry/service/session_service.dart';

final _sharedRiderStatus = ValueNotifier<String?>(null);

class AppBarRider extends StatefulWidget implements PreferredSizeWidget {
  final String riderName;
  final String riderId;
  final String? profileImage;

  const AppBarRider({
    super.key,
    required this.riderName,
    required this.riderId,
    this.profileImage,
  });

  @override
  Size get preferredSize => const Size.fromHeight(80);

  @override
  State<AppBarRider> createState() => _AppBarRiderState();
}

class _AppBarRiderState extends State<AppBarRider> {
  String url = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
 
    final cachedStatus = await Session().getStatus();
    if (cachedStatus != null && cachedStatus.isNotEmpty) {
      _sharedRiderStatus.value = cachedStatus;
    }


    try {
      final config = await Configuration.getConfig();
      url = config['apiEndpoint']?.toString() ?? '';
      await _fetchStatus();
    } catch (_) {}
  }

  Future<void> _fetchStatus() async {
    if (url.isEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('$url/rider/profile/status/${widget.riderId}'),
      );
      if (res.statusCode == 200) {
        final response = riderStatusResponseFromJson(res.body);
        if (response.ok && response.data != null) {
          _sharedRiderStatus.value = response.data!.status;
          await Session().updateStatus(response.data!.status);
        }
      }
    } catch (e) {
      log('fetch error: $e');
 
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (url.isEmpty) return;

    final previousStatus = _sharedRiderStatus.value;
    _sharedRiderStatus.value = newStatus;

    try {
      final res = await http.put(
        Uri.parse('$url/rider/profile/status/${widget.riderId}'),
        headers: {'Content-Type': 'application/json'},
        body: riderStatusRequestToJson(RiderStatusRequest(status: newStatus)),
      );
      if (res.statusCode != 200) {
        _sharedRiderStatus.value = previousStatus;
        return;
      }

      final response = riderStatusResponseFromJson(res.body);
      if (!response.ok) {
        _sharedRiderStatus.value = previousStatus;
      } else {
        await Session().updateStatus(newStatus);
      }
    } catch (e) {
      log('update error: $e');
      _sharedRiderStatus.value = previousStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0593FF), Color(0xFF0476D9)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(color: Color(0x330476D9), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: ClipOval(child: _buildProfileImage()),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.riderName.isEmpty ? 'Rider' : widget.riderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ValueListenableBuilder<String?>(
                      valueListenable: _sharedRiderStatus,
                      builder: (context, status, _) {
                        final isLoading = status == null;

                        return GestureDetector(
                          onTap: isLoading ? null : _showStatusSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isLoading)
                                  const SizedBox(
                                    width: 7,
                                    height: 7,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
                                  )
                                else
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(color: _statusColor(status), shape: BoxShape.circle),
                                  ),
                                const SizedBox(width: 5),
                                Text(
                                  isLoading ? 'กำลังโหลด...' : _statusText(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (!isLoading) ...[
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 14),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    final img = widget.profileImage;
    if (img != null && img.isNotEmpty) {
      return Image.network(
        img,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }
    return _fallback();
  }

  Widget _fallback() => Image.asset(
        'assets/icons/profile_null.png',
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Icon(Icons.motorcycle_rounded, color: Colors.white, size: 26),
      );

  String _statusText(String status) {
    switch (status) {
      case 'ONLINE':
        return 'ออนไลน์';
      case 'TEMP_CLOSED':
        return 'ปิดชั่วคราว';
      default:
        return 'ออฟไลน์';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ONLINE':
        return const Color(0xFF4CD964);
      case 'TEMP_CLOSED':
        return const Color(0xFFFF9500);
      default:
        return const Color(0xFFFF3B30);
    }
  }

  void _showStatusSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ValueListenableBuilder<String?>(
        valueListenable: _sharedRiderStatus,
        builder: (context, status, _) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text(
                'สถานะการทำงาน',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              _statusOption('ONLINE', const Color(0xFF4CD964), status),
              _statusOption('TEMP_CLOSED', const Color(0xFFFF9500), status),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusOption(String value, Color color, String? currentStatus) {
    final isActive = currentStatus == value;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      title: Text(
        _statusText(value),
        style: TextStyle(
          fontSize: 15,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          color: const Color(0xFF1E293B),
        ),
      ),
      trailing: isActive ? Icon(Icons.check_rounded, color: color, size: 20) : null,
      onTap: () {
        Navigator.pop(context);
        _updateStatus(value);
      },
    );
  }
}