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

  /// Clock In — kirim foto selfie + koordinat GPS.
  Future<ClockInResultModel> clockIn({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
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

  /// Clock Out — kirim foto selfie + koordinat GPS.
  Future<Map<String, dynamic>> clockOut({
    required double latitude,
    required double longitude,
    required File photo,
    String? address,
  }) async {
    try {
      final formData = FormData.fromMap({
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
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
      final response = await _apiClient.dio.get(ApiConstants.attendanceHistory);

      final data = response.data['data'] as List;

      return data
          .map(
            (item) =>
                AttendanceHistoryModel.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Ambil info lokasi kantor (untuk validasi radius di sisi UI/peta).
  Future<OfficeLocationModel?> getOfficeLocation() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.officeLocation);

      return OfficeLocationModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      // 404 artinya lokasi kantor belum dikonfigurasi — bukan error fatal
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
      return 'Koneksi timeout. Periksa jaringan internet Anda.';
    }

    if (e.type == DioExceptionType.connectionError) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
    }

    return 'Terjadi kesalahan. Silakan coba lagi.';
  }
}
