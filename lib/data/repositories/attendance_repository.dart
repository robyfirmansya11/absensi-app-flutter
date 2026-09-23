import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository(this._apiClient);

  /// Ambil status absensi hari ini.
  Future<AttendanceTodayModel> getToday() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.attendanceToday);
      return AttendanceTodayModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Clock In — kirim foto selfie + koordinat GPS + alasan (kalau terlambat/luar radius).
  Future<ClockInResultModel> clockIn({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
    String? reason,
    String? locationReason, // ← tambah
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
        if (reason != null) 'reason': reason,
        if (locationReason != null)
          'location_reason': locationReason, // ← tambah
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'clock_in_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        ApiConstants.clockIn,
        data: formData,
      );

      return ClockInResultModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Clock Out — kirim foto + GPS + alasan (kalau pulang lebih awal/luar radius).
  Future<Map<String, dynamic>> clockOut({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
    String? reason,
    String? locationReason, // ← tambah
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
        if (reason != null) 'reason': reason,
        if (locationReason != null)
          'location_reason': locationReason, // ← tambah
        'photo': await MultipartFile.fromFile(
          photo.path,
          filename: 'clock_out_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
      });

      final response = await _apiClient.dio.post(
        ApiConstants.clockOut,
        data: formData,
      );

      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ambil riwayat absensi (paginated dari Laravel).
  Future<List<AttendanceHistoryModel>> getHistory() async {
    try {
      final history = <int, AttendanceHistoryModel>{};
      final session = _apiClient.sessionVersion;
      var page = 1;
      while (true) {
        if (session != _apiClient.sessionVersion) {
          throw StateError(
            'Your session has changed. Refresh the attendance history.',
          );
        }
        final response = await _apiClient.dio.get(
          ApiConstants.attendanceHistory,
          queryParameters: {'page': page},
        );
        final body = response.data as Map<String, dynamic>;
        if (session != _apiClient.sessionVersion) {
          throw StateError(
            'Your session has changed. Refresh the attendance history.',
          );
        }
        final data = body['data'] as List;
        final previousCount = history.length;
        for (final item in data) {
          final attendance = AttendanceHistoryModel.fromJson(
            item as Map<String, dynamic>,
          );
          history[attendance.id] = attendance;
        }
        // Support both Laravel paginator and API Resource envelopes.
        final meta = body['meta'] as Map<String, dynamic>? ?? body;
        final lastPage = int.tryParse('${meta['last_page']}');
        final links = body['links'];
        final next =
            body['next_page_url'] ?? (links is Map ? links['next'] : null);
        final hasNext = lastPage != null ? page < lastPage : next != null;
        if (!hasNext) break;
        if (history.length == previousCount) {
          throw const FormatException('Attendance pagination did not advance.');
        }
        page++;
      }
      return history.values.toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ambil info lokasi kantor (untuk validasi radius di sisi UI).
  Future<OfficeLocationModel?> getOfficeLocation() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.officeLocation);

      return OfficeLocationModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return null;
      }
      throw _handleError(e);
    }
  }

  String _handleError(DioException e) {
    if (e.response != null) {
      final data = e.response!.data;

      if (data is Map<String, dynamic> && data.containsKey('message')) {
        return data['message'] as String;
      }
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'The connection timed out. Check your internet connection and try again.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Unable to connect to the server. Check your internet connection.';
    }

    return 'Something went wrong. Please try again.';
  }
}
