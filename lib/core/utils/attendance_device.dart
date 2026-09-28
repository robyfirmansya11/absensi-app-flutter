import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistent installation identifier for attendance audit records.
/// This is not a hardware identifier or proof of device integrity.
class AttendanceDevice {
  static const _storage = FlutterSecureStorage();
  static const _key = 'attendance_installation_id';
  static Future<String>? _pending;

  static Future<String> getId() => _pending ??= _load().whenComplete(() {
    _pending = null;
  });

  static Future<String> _load() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await _storage.write(key: _key, value: id);
    return id;
  }
}
