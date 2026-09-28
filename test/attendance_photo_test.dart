import 'package:absensi_app_new/core/widgets/network_image_with_host.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());
  Future<void> login() async {
    final client = container.read(apiClientProvider);
    client.dio.httpClientAdapter = ApiStub(
      (r) => jsonResponse({
        'token': 'photo-test-token',
        'user': {'id': 1, 'name': 'Test', 'email': 'test@example.test'},
      }),
    );
    await container
        .read(authProvider.notifier)
        .login('test@example.test', 'test-password');
  }

  Future<List<int>> fetchPhoto(String url) {
    final provider = attendancePhotoProvider(url);
    final subscription = container.listen(provider, (_, _) {});
    addTearDown(subscription.close);
    return container.read(provider.future);
  }

  test(
    'photo request carries bearer token and development host header',
    () async {
      await login();
      final client = container.read(apiClientProvider);
      client.dio.httpClientAdapter = ApiStub((r) {
        expect(r.headers['Authorization'], 'Bearer photo-test-token');
        expect(r.headers['Host'], 'internal-system.test');
        expect(r.followRedirects, isFalse);
        expect(r.responseType, ResponseType.bytes);
        return ResponseBody.fromBytes(
          [1, 2, 3],
          200,
          headers: {
            'content-type': ['image/jpeg'],
          },
        );
      });
      final result = await fetchPhoto(
        'http://internal-system.test/api/v1/attendance/1/photos/clock_in_photo',
      );
      expect(result, [1, 2, 3]);
    },
  );
  test('external photo URLs never receive the token', () async {
    await login();
    var called = false;
    container.read(apiClientProvider).dio.httpClientAdapter = ApiStub((r) {
      called = true;
      return jsonResponse({});
    });
    await expectLater(
      fetchPhoto('https://other.example/photo.jpg'),
      throwsStateError,
    );
    expect(called, isFalse);
  });
  test('signed-out users cannot fetch private photos', () async {
    await expectLater(
      fetchPhoto('http://10.0.2.2/photo.jpg'),
      throwsStateError,
    );
  });
  test('redirect response is not accepted as an image', () async {
    await login();
    container.read(apiClientProvider).dio.httpClientAdapter = ApiStub(
      (r) => ResponseBody.fromBytes(
        [],
        302,
        headers: {
          'location': ['https://other.example/photo.jpg'],
        },
      ),
    );
    await expectLater(
      fetchPhoto('http://10.0.2.2/photo.jpg'),
      throwsA(isA<DioException>()),
    );
  });
}
