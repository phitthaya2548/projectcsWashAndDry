import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Session {
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      resetOnError: false,
    ),
  );

  static const _kRole = 'role';
  static const _kCustomerId = 'customer_id';
  static const _kStoreId = 'store_id';
  static const _kRiderId = 'rider_id';
  static const _kStaffId = 'staff_id';
  static const _kFullname = 'fullname';
  static const _kPhone = 'phone';
  static const _kProfileImage = 'profile_image';
  static const _kgoogleId = 'google_id';
  static const _kStatus = 'status';
  static const _kFcmToken = 'fcm_token';

  Future<void> saveLogin({
    required String role,
    String? customerId,
    String? storeId,
    String? riderId,
    String? staffId,
    String? fullname,
    String? profileImage,
    String? phone,
    String? googleId,
    String? status,
    String? fcmToken,
  }) async {
    await _storage.write(key: _kRole, value: role);

    await _storage.write(
      key: _kFcmToken,
      value: fcmToken ?? '',
    );

    await _storage.write(key: _kCustomerId, value: '');
    await _storage.write(key: _kStoreId, value: '');
    await _storage.write(key: _kRiderId, value: '');
    await _storage.write(key: _kStaffId, value: '');
    await _storage.write(key: _kStatus, value: '');

    if (role == 'customer') {
      await _storage.write(
        key: _kCustomerId,
        value: customerId ?? '',
      );
    } else if (role == 'store') {
      await _storage.write(
        key: _kStoreId,
        value: storeId ?? '',
      );

      await _storage.write(
        key: _kStatus,
        value: status ?? '',
      );
    } else if (role == 'rider') {
      await _storage.write(
        key: _kRiderId,
        value: riderId ?? '',
      );

      await _storage.write(
        key: _kStoreId,
        value: storeId ?? '',
      );

      await _storage.write(
        key: _kStatus,
        value: status ?? '',
      );
    } else if (role == 'laundry_staff') {
      await _storage.write(
        key: _kStaffId,
        value: staffId ?? '',
      );

      await _storage.write(
        key: _kStoreId,
        value: storeId ?? '',
      );

      await _storage.write(
        key: _kStatus,
        value: status ?? '',
      );
    }

    await _storage.write(
      key: _kPhone,
      value: phone ?? '',
    );

    await _storage.write(
      key: _kFullname,
      value: fullname ?? '',
    );

    await _storage.write(
      key: _kProfileImage,
      value: profileImage ?? '',
    );

    await _storage.write(
      key: _kgoogleId,
      value: googleId ?? '',
    );
  }

  Future<String?> getRole() =>
      _storage.read(key: _kRole);

  Future<String?> getCustomerId() =>
      _storage.read(key: _kCustomerId);

  Future<String?> getStoreId() =>
      _storage.read(key: _kStoreId);

  Future<String?> getRiderId() =>
      _storage.read(key: _kRiderId);

  Future<String?> getStaffId() =>
      _storage.read(key: _kStaffId);

  Future<String?> getFullname() =>
      _storage.read(key: _kFullname);

  Future<String?> getPhone() =>
      _storage.read(key: _kPhone);

  Future<String?> getProfileImage() =>
      _storage.read(key: _kProfileImage);

  Future<String?> getgoogleId() =>
      _storage.read(key: _kgoogleId);

  Future<String?> getStatus() =>
      _storage.read(key: _kStatus);

  Future<String?> getFcmToken() =>
      _storage.read(key: _kFcmToken);

  Future<void> updateStatus(String status) =>
      _storage.write(
        key: _kStatus,
        value: status,
      );

  Future<void> updateStoreId(String storeId) =>
      _storage.write(
        key: _kStoreId,
        value: storeId,
      );

  Future<void> clearEmployeeStore() async {
    await _storage.write(
      key: _kStoreId,
      value: '',
    );

    await _storage.write(
      key: _kStatus,
      value: '',
    );
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }
}