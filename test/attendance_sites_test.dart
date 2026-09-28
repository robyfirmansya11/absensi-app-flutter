import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/core/utils/attendance_location.dart';
import 'package:absensi_app_new/data/models/attendance_model.dart';
import 'package:absensi_app_new/data/repositories/attendance_repository.dart';
import 'package:absensi_app_new/presentation/screens/attendance/attendance_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

Map<String, dynamic> site(String name, double lat, {int radius = 100}) => {
  'name': name,
  'latitude': lat,
  'longitude': 0.0,
  'radius': radius,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('uses all active sites rather than legacy primary fields', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub(
      (r) => jsonResponse({
        ...site('Head Office', 0),
        'locations': [site('Head Office', 0), site('Site B', 1)],
      }),
    );
    final sites = await AttendanceRepository(client).getOfficeLocations();
    final match = AttendanceOfficeMatch.nearest(sites, 1, 0)!;
    expect(sites, hasLength(2));
    expect(match.office.name, 'Site B');
    expect(match.isOutsideRadius, isFalse);
    expect(
      AttendanceOfficeMatch.nearest(sites, 0, 0)!.office.name,
      'Head Office',
    );
  });
  test('legacy single office response still works', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub(
      (r) => jsonResponse(site('Legacy', 0)),
    );
    expect(
      (await AttendanceRepository(client).getOfficeLocations()).single.name,
      'Legacy',
    );
  });
  test('no active office and network errors remain distinct', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub(
      (r) => jsonResponse({'message': 'No office'}, status: 404),
    );
    expect(await AttendanceRepository(client).getOfficeLocations(), isEmpty);
    client.dio.httpClientAdapter = ApiStub(
      (r) => jsonResponse({'message': 'Server unavailable'}, status: 500),
    );
    await expectLater(
      AttendanceRepository(client).getOfficeLocations(),
      throwsA('Server unavailable'),
    );
  });
  test(
    'nearest-site radius and rounding match backend including overlapping sites',
    () {
      final sites = [
        OfficeLocationModel.fromJson(site('Near small site', 0, radius: 10)),
        OfficeLocationModel.fromJson(
          site('Far large site', 0.002, radius: 1000),
        ),
      ];
      expect(
        AttendanceOfficeMatch.nearest(sites, 0.0005, 0)!.isOutsideRadius,
        isTrue,
      );
      final origin = OfficeLocationModel.fromJson(site('Origin', 0));
      expect(AttendanceOfficeMatch.nearest([origin], 0.0009, 0)!.distance, 100);
      expect(
        AttendanceOfficeMatch.nearest([origin], 0.0009, 0)!.isOutsideRadius,
        isFalse,
      );
      expect(
        AttendanceOfficeMatch.nearest([origin], 0.001, 0)!.isOutsideRadius,
        isTrue,
      );
      expect(AttendanceOfficeMatch.nearest([], 0, 0), isNull);
    },
  );
  testWidgets(
    'history preserves and displays separate clock-in and clock-out sites',
    (tester) async {
      final row = {
        ...historyRow(1),
        'clock_in_office_location': site('Head Office', 0),
        'clock_out_office_location': site('Site B', 1),
      };
      final record = AttendanceHistoryModel.fromJson(row);
      final today = AttendanceTodayModel.fromJson({
        ...row,
        'has_clocked_in': true,
        'has_clocked_out': true,
      });
      expect(today.clockInOfficeLocation!.name, 'Head Office');
      expect(today.clockOutOfficeLocation!.name, 'Site B');
      expect(
        AttendanceHistoryModel.fromJson(historyRow(2)).clockInOfficeLocation,
        isNull,
      );
      await tester.pumpWidget(
        MaterialApp(home: AttendanceDetailScreen(attendance: record)),
      );
      expect(find.text('Head Office'), findsOneWidget);
      expect(find.text('Site B'), findsOneWidget);
    },
  );
}
