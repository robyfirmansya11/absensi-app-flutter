import 'dart:async';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/providers/attendance_provider.dart';
import 'package:absensi_app_new/presentation/providers/cuti_provider.dart';
import 'package:absensi_app_new/presentation/providers/cuti_approval_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late ApiClient client;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    container = ProviderContainer();
    client = container.read(apiClientProvider);
  });
  tearDown(() => container.dispose());
  Future<bool> login(String account) =>
      container.read(authProvider.notifier).login(account, 'password');
  ResponseBody respond(RequestOptions request) {
    switch (request.path) {
      case '/login':
        final email = request.data['email'];
        return jsonResponse({
          'token': 'token-$email',
          'user': {'id': email == 'a' ? 1 : 2, 'name': email, 'email': email},
        });
      case '/logout':
        return jsonResponse({});
      case '/attendance/today':
        return jsonResponse({
          'date': '2026-09-18',
          'has_clocked_in': true,
          'has_clocked_out': false,
        });
      case '/attendance/history':
        return jsonResponse({
          'data': [historyRow(1)],
        });
      case '/cuti':
      case '/cuti/approvals':
        return jsonResponse([leaveRow(1)]);
      case '/cuti/quota':
        return jsonResponse({
          'tahun': 2026,
          'kuota_tahunan': 12,
          'cuti_terpakai': 1,
          'sisa_cuti': 11,
        });
      default:
        throw StateError('Unexpected request: ${request.path}');
    }
  }

  test('logout clears attendance, leave quota and approvals', () async {
    client.dio.httpClientAdapter = ApiStub(respond);
    expect(await login('a'), isTrue);
    await container.read(attendanceProvider.notifier).loadToday();
    await container.read(attendanceProvider.notifier).loadHistory();
    await container.read(cutiProvider.notifier).loadAll();
    await container.read(cutiApprovalProvider.notifier).loadAll();
    expect(container.read(attendanceProvider).history, hasLength(1));
    expect(container.read(cutiProvider).quota, isNotNull);
    expect(container.read(cutiApprovalProvider).list, hasLength(1));
    await container.read(authProvider.notifier).logout();
    expect(container.read(attendanceProvider).today, isNull);
    expect(container.read(attendanceProvider).history, isEmpty);
    expect(container.read(cutiProvider).list, isEmpty);
    expect(container.read(cutiProvider).quota, isNull);
    expect(container.read(cutiApprovalProvider).list, isEmpty);
    expect(await client.getToken(), isNull);
  });

  test('late responses from account A cannot populate account B', () async {
    client.dio.httpClientAdapter = ApiStub(respond);
    await login('a');
    final release = Completer<void>();
    final started = Completer<void>();
    var requests = 0;
    client.dio.httpClientAdapter = ApiStub((request) async {
      if (request.path != '/login') {
        if (++requests == 4) started.complete();
        await release.future;
      }
      return respond(request);
    });
    final pending = Future.wait([
      container.read(attendanceProvider.notifier).loadHistory(),
      container.read(cutiProvider.notifier).loadAll(),
      container.read(cutiApprovalProvider.notifier).loadAll(),
    ]);
    await started.future;
    container.read(authProvider.notifier).clearSession();
    await login('b');
    expect(container.read(attendanceProvider).history, isEmpty);
    expect(container.read(cutiProvider).quota, isNull);
    expect(container.read(cutiApprovalProvider).list, isEmpty);
    release.complete();
    await pending;
    expect(container.read(authProvider).user!.id, 2);
    expect(container.read(attendanceProvider).history, isEmpty);
    expect(container.read(cutiProvider).list, isEmpty);
    expect(container.read(cutiApprovalProvider).list, isEmpty);
  });

  for (final status in [null, 503]) {
    test('profile failure $status keeps token and allows retry', () async {
      await client.saveToken('valid-token');
      var fail = true;
      client.dio.httpClientAdapter = ApiStub((request) {
        expect(request.path, '/me');
        if (fail) {
          if (status == null) {
            throw DioException(
              requestOptions: request,
              type: DioExceptionType.connectionTimeout,
            );
          }
          return jsonResponse({'message': 'Unavailable'}, status: status);
        }
        return jsonResponse({'id': 1, 'name': 'A', 'email': 'a'});
      });
      await container.read(authProvider.notifier).checkAuthStatus();
      expect(await client.getToken(), 'valid-token');
      expect(container.read(authProvider).errorMessage, isNotNull);
      fail = false;
      await container.read(authProvider.notifier).checkAuthStatus();
      expect(container.read(authProvider).user!.id, 1);
      expect(container.read(authProvider).errorMessage, isNull);
    });
  }

  test('current session 401 clears auth and user data', () async {
    client.dio.httpClientAdapter = ApiStub(respond);
    await login('a');
    await container.read(attendanceProvider.notifier).loadToday();
    client.dio.httpClientAdapter = ApiStub(
      (_) => jsonResponse({}, status: 401),
    );
    await container.read(authProvider.notifier).checkAuthStatus();
    expect(await client.getToken(), isNull);
    expect(container.read(authProvider).user, isNull);
    expect(container.read(attendanceProvider).today, isNull);
  });

  test('late 401 from previous token does not log out new account', () async {
    client.dio.httpClientAdapter = ApiStub(respond);
    await login('a');
    final started = Completer<void>();
    final release = Completer<void>();
    client.dio.httpClientAdapter = ApiStub((request) async {
      if (request.path == '/me') {
        started.complete();
        await release.future;
        return jsonResponse({}, status: 401);
      }
      return respond(request);
    });
    final pending = client.dio.get('/me');
    final assertion = expectLater(pending, throwsA(isA<DioException>()));
    await started.future;
    await login('b');
    release.complete();
    await assertion;
    expect(await client.getToken(), 'token-b');
    expect(container.read(authProvider).user!.id, 2);
  });
}
