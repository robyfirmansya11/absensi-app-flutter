import 'package:flutter_test/flutter_test.dart';
import 'package:absensi_app_new/core/utils/english_ui.dart';

void main() {
  test('dates use English month names without locale initialization', () {
    expect(EnglishUi.date('2026-08-23'), '23 Aug 2026');
    expect(EnglishUi.date(''), '');
  });

  test('leave labels preserve unrecognized values', () {
    expect(EnglishUi.leaveType('Cuti Tahunan'), 'Annual Leave');
    expect(EnglishUi.leaveType('Custom leave'), 'Custom leave');
  });

  test('API errors translate messages without changing field keys or data', () {
    final data = {
      'message': 'Nomor surat sudah digunakan.',
      'errors': {
        'nomor_surat': ['Nomor surat sudah digunakan.'],
      },
      'description': 'Kunjungan kantor',
    };
    EnglishUi.localizeError(data);
    expect(data['message'], 'This letter number is already in use.');
    expect((data['errors'] as Map)['nomor_surat'], [
      'This letter number is already in use.',
    ]);
    expect(data['description'], 'Kunjungan kantor');
    expect(
      EnglishUi.apiMessage('Custom server message'),
      'Custom server message',
    );
  });
}
