import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/core/utils/attendance_location.dart';
import 'package:absensi_app_new/data/repositories/attendance_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'support/api_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  for (final resourceEnvelope in [false, true]) {
    test('loads all history pages (resource=$resourceEnvelope)', () async {
      final client = ApiClient();
      final pages = <int>[];
      client.dio.httpClientAdapter = ApiStub((request) {
        final page = request.queryParameters['page'] as int;
        pages.add(page);
        return jsonResponse({
          'data': [historyRow(page)],
          if (resourceEnvelope) 'meta': {'last_page': 3} else 'last_page': 3,
        });
      });
      final rows = await AttendanceRepository(client).getHistory();
      expect(rows.map((row) => row.id), [1, 2, 3]);
      expect(pages, [1, 2, 3]);
    });
  }
  test('simple paginator follows pages without following remote URL', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/attendance/history');
      final page = request.queryParameters['page'] as int;
      return jsonResponse({
        'data': [historyRow(page)],
        'next_page_url': page == 1 ? 'https://other.example/?page=2' : null,
      });
    });
    expect(await AttendanceRepository(client).getHistory(), hasLength(2));
  });
  test('broken pagination fails instead of looping indefinitely', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub(
      (_) => jsonResponse({
        'data': [historyRow(1)],
        'last_page': 5,
      }),
    );
    await expectLater(
      AttendanceRepository(client).getHistory(),
      throwsFormatException,
    );
  });
  final now = DateTime(2026, 9, 18, 8);
  Position position({int secondsOld = 0, double accuracy = 10}) => Position(
    longitude: 121,
    latitude: -2,
    timestamp: now.subtract(Duration(seconds: secondsOld)),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  test('accepts fresh accurate GPS fix', () {
    expect(
      () => AttendanceLocation.validate(position(), now: now),
      returnsNormally,
    );
  });
  test('rejects old or inaccurate GPS fixes', () {
    expect(
      () => AttendanceLocation.validate(position(secondsOld: 31), now: now),
      throwsStateError,
    );
    expect(
      () => AttendanceLocation.validate(position(accuracy: 100), now: now),
      throwsStateError,
    );
  });
}
