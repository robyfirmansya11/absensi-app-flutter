import 'dart:async';
import 'package:absensi_app_new/core/constants/app_config.dart';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/overtime_model.dart';
import 'package:absensi_app_new/data/repositories/overtime_repository.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/providers/overtime_provider.dart';
import 'package:absensi_app_new/presentation/screens/overtime/overtime_screen.dart';
import 'package:absensi_app_new/presentation/screens/overtime/create_overtime_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

OvertimeDraft draft({String end = '19:00', double? meal = 25000}) =>
    OvertimeDraft(
      month: DateTime(2026, 9),
      date: DateTime(2026, 9, 21),
      workStart: '08:00',
      workEnd: '17:00',
      overtimeStart: '17:30',
      overtimeEnd: end,
      mealAllowance: meal,
      description: ' Pekerjaan lembur ',
    );

Map<String, dynamic> row(int id, {String status = 'Pending Approval'}) => {
  ...draft().toJson(),
  'id': id,
  'status': status,
  'approval_level': 1,
  'can_cancel': status == 'Pending Approval',
  'jumlah_jam_lembur': '1.50',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('draft validates times and sends Filament fields', () {
    expect(draft().hours, 1.5);
    expect(draft().toJson()['bulan_lembur'], '2026-09');
    expect(draft().toJson()['uraian_pekerjaan'], 'Pekerjaan lembur');
    expect(draft(end: '17:30').validate(), isNotNull);
    expect(draft(end: '01:00').validate(), isNotNull);
    expect(draft(end: '25:00').validate(), isNotNull);
    expect(draft(meal: -1).validate(), isNotNull);
  });

  test('model reads decimal strings and workflow status', () {
    final record = OvertimeModel.fromJson(row(1));
    expect(record.hours, 1.5);
    expect(record.statusLabel, 'Awaiting Supervisor Approval');
    expect(record.canCancel, isTrue);
    expect(
      OvertimeModel.fromJson(row(1, status: 'Cancelled')).statusLabel,
      'Cancelled',
    );
  });

  test('repository uses development host and loads every page', () async {
    expect(AppConfig.isDevelopment, isTrue);
    final client = ApiClient();
    final pages = <int>[];
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.uri.host, '10.0.2.2');
      expect(request.headers['Host'], 'internal-system.test');
      final page = request.queryParameters['page'] as int;
      pages.add(page);
      return jsonResponse({
        'data': [row(page)],
        'last_page': 2,
      });
    });
    expect(await OvertimeRepository(client).getList(), hasLength(2));
    expect(pages, [1, 2]);
  });

  test(
    'create sends validated body and exposes server validation errors',
    () async {
      final client = ApiClient();
      client.dio.httpClientAdapter = ApiStub((request) {
        expect(request.path, '/overtime');
        expect(request.method, 'POST');
        expect(request.data['mulai_lembur'], '17:30');
        expect(request.data['user_id'], isNull);
        return jsonResponse({
          'message': 'Invalid',
          'errors': {
            'tanggal_lembur': ['Tanggal tidak valid.'],
          },
        }, status: 422);
      });
      await expectLater(
        OvertimeRepository(client).create(draft()),
        throwsA('Tanggal tidak valid.'),
      );
    },
  );

  test(
    'duplicate submits are blocked and old account response is discarded',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final client = container.read(apiClientProvider);
      final started = Completer<void>();
      final release = Completer<void>();
      var creates = 0;
      client.dio.httpClientAdapter = ApiStub((request) async {
        if (request.path == '/login') {
          return jsonResponse({
            'token': 'token',
            'user': {'id': 1, 'name': 'A', 'email': 'a'},
          });
        }
        creates++;
        started.complete();
        await release.future;
        return jsonResponse({'data': row(1)}, status: 201);
      });
      await container.read(authProvider.notifier).login('a', 'password');
      final notifier = container.read(overtimeProvider.notifier);
      final pending = notifier.create(draft());
      await started.future;
      expect(await notifier.create(draft()), isFalse);
      container.read(authProvider.notifier).clearSession();
      expect(container.read(overtimeProvider).records, isEmpty);
      release.complete();
      expect(await pending, isFalse);
      expect(creates, 1);
      expect(container.read(overtimeProvider).records, isEmpty);
    },
  );

  testWidgets('list retries errors and cancellation updates status', (
    tester,
  ) async {
    final client = ApiClient();
    var fail = true;
    client.dio.httpClientAdapter = ApiStub((request) {
      if (request.method == 'POST') {
        return jsonResponse({'data': row(1, status: 'Cancelled')});
      }
      if (fail) {
        return jsonResponse({'message': 'Server tidak tersedia'}, status: 503);
      }
      return jsonResponse({
        'data': [row(1)],
        'last_page': 1,
      });
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: OvertimeScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server tidak tersedia'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting Supervisor Approval'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('form requires work description before sending', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CreateOvertimeScreen())),
    );
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(find.text('Provide a work description.'), findsOneWidget);
  });
}
