import 'dart:typed_data';
import 'dart:io';

import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/core/utils/attendance_device.dart';
import 'package:absensi_app_new/data/repositories/attendance_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'installation ID persists across calls and authentication logout',
    () async {
      final ids = await Future.wait(
        List.generate(3, (_) => AttendanceDevice.getId()),
      );
      expect(ids.toSet(), hasLength(1));
      expect(ids.first, matches(RegExp(r'^[0-9a-f]{64}$')));
      await ApiClient().clearToken();
      expect(await AttendanceDevice.getId(), ids.first);
    },
  );

  test(
    'both attendance endpoints send GPS accuracy and the same installation ID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'attendance-upload-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final photo = await File(
        '${directory.path}/selfie.jpg',
      ).writeAsBytes([1, 2, 3]);
      final client = ApiClient();
      final payloads = <Map<String, String>>[];
      final paths = <String>[];
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            final form = options.data as FormData;
            payloads.add(Map.fromEntries(form.fields));
            paths.add(options.path);
            expect(form.files.single.key, 'photo');
            handler.next(options);
          },
        ),
      );
      client.dio.httpClientAdapter = _UploadStub(
        (_) => jsonResponse({
          'message': 'Success',
          'clock_in': '08:00',
          'status': 'present',
        }),
      );
      final repo = AttendanceRepository(client);
      await repo.clockIn(
        latitude: -6.17,
        longitude: 106.79,
        gpsAccuracy: 39.5,
        isMockLocation: false,
        photo: photo,
      );
      await repo.clockOut(
        latitude: -6.18,
        longitude: 106.80,
        gpsAccuracy: 12.25,
        isMockLocation: true,
        photo: photo,
      );
      expect(paths, ['/attendance/clock-in', '/attendance/clock-out']);
      expect(payloads[0]['gps_accuracy'], '39.5');
      expect(payloads[1]['gps_accuracy'], '12.25');
      expect(payloads[0]['is_mock_location'], '0');
      expect(payloads[1]['is_mock_location'], '1');
      expect(payloads[0]['device_id'], isNotEmpty);
      expect(payloads[1]['device_id'], payloads[0]['device_id']);
      expect(payloads[0].containsKey('device_integrity_status'), isFalse);
    },
  );
}

class _UploadStub extends ApiStub {
  _UploadStub(super.respond);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await requestStream?.drain<void>();
    return super.fetch(options, null, cancelFuture);
  }
}
