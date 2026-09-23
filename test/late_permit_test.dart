import 'dart:async';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/late_permit_model.dart';
import 'package:absensi_app_new/data/repositories/late_permit_repository.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/providers/late_permit_provider.dart';
import 'package:absensi_app_new/presentation/screens/late_permit/late_permit_screen.dart';
import 'package:absensi_app_new/presentation/screens/late_permit/create_late_permit_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

LatePermitDraft draft() => LatePermitDraft(
  date: DateTime(2026, 1, 1),
  arrivalTime: '09:15',
  reason: ' Kendaraan bermasalah ',
);
Map<String, dynamic> row(int id, {String status = 'Pending Approval'}) => {
  ...draft().toJson(),
  'id': id,
  'status': status,
  'approval_level': 1,
  'can_cancel': status == 'Pending Approval',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('validates future date, arrival time and reason', () {
    final today = DateTime(2026, 9, 21);
    expect(draft().validate(now: today), isNull);
    expect(
      LatePermitDraft(
        date: today.add(const Duration(days: 1)),
        arrivalTime: '09:00',
        reason: 'Test',
      ).validate(now: today),
      isNotNull,
    );
    expect(
      LatePermitDraft(
        date: today,
        arrivalTime: '24:00',
        reason: 'Test',
      ).validate(now: today),
      isNotNull,
    );
    expect(
      LatePermitDraft(
        date: today,
        arrivalTime: '09:00',
        reason: '  ',
      ).validate(now: today),
      isNotNull,
    );
    expect(draft().toJson(), {
      'tanggal': '2026-01-01',
      'jam_masuk': '09:15',
      'alasan': 'Kendaraan bermasalah',
    });
  });

  test('loads all pages using development endpoint', () async {
    final client = ApiClient();
    final pages = <int>[];
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/late-working-permits');
      expect(request.uri.host, '10.0.2.2');
      expect(request.headers['Host'], 'internal-system.test');
      final page = request.queryParameters['page'] as int;
      pages.add(page);
      return jsonResponse({
        'data': [row(page)],
        'last_page': 2,
      });
    });
    final result = await LatePermitRepository(client).getList();
    expect(result, hasLength(2));
    expect(pages, [1, 2]);
    expect(result.first.statusLabel, 'Awaiting Supervisor Approval');
  });

  test('server validation error is shown without losing draft', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.data, draft().toJson());
      return jsonResponse({
        'errors': {
          'tanggal': ['Tanggal tidak valid.'],
        },
      }, status: 422);
    });
    await expectLater(
      LatePermitRepository(client).create(draft()),
      throwsA('Tanggal tidak valid.'),
    );
  });

  test('blocks duplicate submit and discards old session response', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(apiClientProvider);
    final started = Completer<void>();
    final release = Completer<void>();
    var count = 0;
    client.dio.httpClientAdapter = ApiStub((request) async {
      if (request.path == '/login') {
        return jsonResponse({
          'token': 'token',
          'user': {'id': 1, 'name': 'A', 'email': 'a'},
        });
      }
      count++;
      started.complete();
      await release.future;
      return jsonResponse({'data': row(1)}, status: 201);
    });
    await container.read(authProvider.notifier).login('a', 'password');
    final notifier = container.read(latePermitProvider.notifier);
    final pending = notifier.create(draft());
    await started.future;
    expect(await notifier.create(draft()), isFalse);
    container.read(authProvider.notifier).clearSession();
    expect(container.read(latePermitProvider).records, isEmpty);
    release.complete();
    expect(await pending, isFalse);
    expect(count, 1);
    expect(container.read(latePermitProvider).records, isEmpty);
  });

  testWidgets('list can retry and cancel a pending permit', (tester) async {
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
        child: const MaterialApp(home: LatePermitScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server tidak tersedia'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('Arrival Time: 09:15'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Request'));
    await tester.pumpAndSettle();
    expect(find.text('Cancelled'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('form sends selected arrival and reason', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final client = container.read(apiClientProvider);
    var sent = false;
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.data['jam_masuk'], '09:15');
      expect(request.data['alasan'], 'Kendaraan bermasalah');
      sent = true;
      return jsonResponse({
        'data': {...row(1), ...Map<String, dynamic>.from(request.data)},
      }, status: 201);
    });
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CreateLatePermitScreen()),
      ),
    );
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(
      find.text('Provide a reason for your late arrival.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextFormField), 'Kendaraan bermasalah');
    await tester.tap(find.text('Arrival Time: Select Arrival Time'));
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.byType(TimePickerDialog)),
    ).pop(const TimeOfDay(hour: 9, minute: 15));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    expect(sent, isTrue);
    expect(
      container.read(latePermitProvider).records.single.arrivalTime,
      '09:15',
    );
  });
}
