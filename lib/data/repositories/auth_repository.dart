import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Login dengan email & password.
  /// Return UserModel kalau berhasil, throw Exception kalau gagal.
  Future<UserModel> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      final token = response.data['token'] as String;
      final userJson = response.data['user'] as Map<String, dynamic>;

      await _apiClient.saveToken(token);

      return UserModel.fromJson(userJson);
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Logout — hapus token dari server & local storage.
  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiConstants.logout);
    } on DioException catch (_) {
      // Tetap lanjut hapus token lokal meski request gagal
      // (misal karena tidak ada internet)
    } finally {
      await _apiClient.clearToken();
    }
  }

  /// Ambil profile user yang sedang login.
  Future<UserModel> getProfile() async {
    // Preserve HTTP status so a temporary outage is not treated as logout.
    final response = await _apiClient.dio.get(ApiConstants.me);
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Cek apakah user sudah login (ada token tersimpan).
  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getToken();
    return token != null;
  }

  /// Konversi DioException jadi pesan error yang mudah dibaca.
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
