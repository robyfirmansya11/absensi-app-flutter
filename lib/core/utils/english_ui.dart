import 'package:intl/intl.dart';

/// English display labels; API values and user-entered content remain unchanged.
class EnglishUi {
  static String leaveType(String value) =>
      const {
        'Cuti Tahunan': 'Annual Leave',
        'Cuti Haid': 'Menstrual Leave',
        'Cuti Khusus': 'Special Leave',
        'Cuti Melahirkan': 'Maternity Leave',
        'Cuti Keguguran': 'Miscarriage Leave',
        'Cuti Sakit': 'Sick Leave',
      }[value] ??
      value;
  static String date(String value) {
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? value
        : DateFormat('dd MMM yyyy', 'en_US').format(parsed);
  }

  static String apiMessage(String value) {
    const messages = {
      'Kuota cuti untuk tahun ini tidak ditemukan.':
          'No leave quota is available for this year. Contact HR.',
      'User belum memiliki department.':
          'Your account has not been assigned to a department. Contact your administrator.',
      'Akun belum memiliki department.':
          'Your account has not been assigned to a department. Contact your administrator.',
      'Akun belum memiliki atasan langsung yang valid. Hubungi HR atau IT.':
          'Your account does not have a valid direct supervisor. Contact HR or IT.',
      'Lampiran gagal disimpan.': 'Unable to save the attachment.',
      'Permohonan tidak dapat diedit pada status ini.':
          'This request cannot be edited in its current status.',
      'Pengajuan tidak dapat diedit pada status ini.':
          'This request cannot be edited in its current status.',
      'Permohonan tidak dapat dibatalkan.': 'This request cannot be cancelled.',
      'Pengajuan tidak dapat dibatalkan.': 'This request cannot be cancelled.',
      'Pengajuan ini tidak dapat dibatalkan.':
          'This request cannot be cancelled.',
      'Nomor surat sudah digunakan.': 'This letter number is already in use.',
      'Nominal dan total tagihan harus lebih dari nol, total maksimal Rp 999.999.999.999.':
          'The amount and total must be greater than zero. The total must not exceed IDR 999,999,999,999.',
      'Total maksimal Rp 999.999.999.999,99.':
          'The total must not exceed IDR 999,999,999,999.99.',
      'Waktu tiba tidak boleh sebelum keberangkatan.':
          'Arrival cannot be earlier than departure.',
      'Anda sudah melakukan clock in hari ini.':
          'You have already clocked in today.',
      'Anda belum melakukan clock in hari ini.':
          'You have not clocked in today.',
      'Anda sudah melakukan clock out hari ini.':
          'You have already clocked out today.',
      'Anda terlambat. Harap isi alasan keterlambatan.':
          'Please provide a reason for your late arrival.',
      'Anda pulang lebih awal dari jam 17:00. Harap isi alasan.':
          'Please provide a reason for clocking out before 17:00.',
      'Anda tidak memiliki akses untuk melihat halaman ini.':
          'You do not have permission to view this page.',
      'Pengajuan tidak dapat disetujui. Kemungkinan sudah diproses atau Anda tidak berwenang.':
          'This request cannot be approved. It may have been processed, or you may not have permission.',
      'Anda tidak berwenang menolak pengajuan ini.':
          'You do not have permission to reject this request.',
      'Tanggal cuti bertabrakan dengan pengajuan yang sudah ada.':
          'The selected leave dates overlap an existing request.',
      'Pengajuan cuti HRD memerlukan atasan langsung. Silakan hubungi administrator.':
          'A direct supervisor is required for this HR leave request. Contact your administrator.',
      'Pengajuan lembur HRD memerlukan atasan langsung. Silakan hubungi administrator.':
          'A direct supervisor is required for this HR overtime request. Contact your administrator.',
    };
    if (messages.containsKey(value)) return messages[value]!;
    final radius = RegExp(
      r'^Anda berada di luar radius kantor \((.+)m dari kantor, maksimal (.+)m\)\. Harap isi alasan\.$',
    ).firstMatch(value);
    if (radius != null) {
      return 'You are outside the office radius (${radius[1]} m away; maximum ${radius[2]} m). Please provide a reason.';
    }
    final quota = RegExp(
      r'^Kuota cuti tidak mencukupi\. Sisa: (.+) hari, dibutuhkan: (.+) hari\.$',
    ).firstMatch(value);
    if (quota != null) {
      return 'Insufficient leave balance. Remaining: ${quota[1]} days; requested: ${quota[2]} days.';
    }
    final remainingQuota = RegExp(
      r'^Sisa kuota (.+) hari, dibutuhkan (.+) hari\.$',
    ).firstMatch(value);
    if (remainingQuota != null) {
      return 'Insufficient leave balance. Remaining: ${remainingQuota[1]} days; requested: ${remainingQuota[2]} days.';
    }
    return value;
  }

  static void localizeError(Map data) {
    if (data['message'] is String) {
      data['message'] = apiMessage(data['message']);
    }
    final errors = data['errors'];
    if (errors is Map) {
      for (final key in errors.keys.toList()) {
        final messages = errors[key];
        if (messages is List) {
          for (var i = 0; i < messages.length; i++) {
            if (messages[i] is String) {
              messages[i] = apiMessage(messages[i]);
            }
          }
        }
      }
    }
  }
}
