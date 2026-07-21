import 'app_config.dart';

class ApiConstants {
  // Base URL diambil dari AppConfig — tidak perlu ganti manual lagi
  static String get baseUrl => AppConfig.baseUrl;

  // Auth
  static const String login = '/login';
  static const String logout = '/logout';
  static const String me = '/me';

  // Attendance
  static const String attendanceToday = '/attendance/today';
  static const String clockIn = '/attendance/clock-in';
  static const String clockOut = '/attendance/clock-out';
  static const String attendanceHistory = '/attendance/history';
  static const String officeLocation = '/attendance/office-location';
}
