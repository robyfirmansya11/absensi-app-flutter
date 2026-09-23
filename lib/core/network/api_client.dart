import '../utils/english_ui.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../main.dart'; // ← import navigatorKey
import '../constants/api_constants.dart';
import '../constants/app_config.dart';
import '../../presentation/screens/login_screen.dart';

class ApiClient {
  late final Dio dio;
  final _storage = const FlutterSecureStorage();
  final void Function()? onUnauthorized;
  int _sessionVersion = 0;
  int get sessionVersion => _sessionVersion;

  ApiClient({this.onUnauthorized}) {
    final Map<String, String> headers = {
      'Accept': 'application/json',
      'Accept-Language': 'en',
    };

    if (AppConfig.hostHeader != null) {
      headers['Host'] = AppConfig.hostHeader!;
    }

    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: headers,
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await getToken();
          options.extra['sessionVersion'] = _sessionVersion;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          final body = error.response?.data;
          if (body is Map) EnglishUi.localizeError(body);
          final request = error.requestOptions;
          final token = await getToken();
          if (error.response?.statusCode == 401 &&
              request.path != ApiConstants.login &&
              token != null &&
              request.headers['Authorization'] == 'Bearer $token' &&
              request.extra['sessionVersion'] == _sessionVersion) {
            await clearToken();
            onUnauthorized?.call();

            // Redirect ke Login menggunakan global navigatorKey
            navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<void> saveToken(String token) async {
    _sessionVersion++;
    await _storage.write(key: 'auth_token', value: token);
  }

  Future<void> clearToken() async {
    _sessionVersion++;
    await _storage.delete(key: 'auth_token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }
}
