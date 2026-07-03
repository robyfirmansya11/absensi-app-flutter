class ApiConstants {
  // IP komputer kamu di jaringan WiFi lokal — pastikan
  // HP/emulator terhubung ke WiFi yang sama dengan komputer ini.
  static const String baseUrl = 'http://10.0.2.2/api/v1';

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
