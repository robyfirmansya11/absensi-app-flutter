import 'app_config.dart';

class ApiConstants {
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

  // Cuti
  static const String cuti = '/cuti';
  static const String overtime = '/overtime';
  static const String latePermit = '/late-working-permits';
  static const String travel = '/travel-reimbursements';
  static const String expense = '/expense-reimbursements';
  static const String loan = '/loan-notes';
  static const String stamp = '/stamp-applications';
  static const String registerLetter = '/register-letters';
  static const String payment = '/payment-applications';
  static const String cutiQuota = '/cuti/quota';
  static const String cutiApprovals = '/cuti/approvals'; // ⬅️ TAMBAHAN
}
