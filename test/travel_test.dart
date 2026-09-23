import 'dart:async';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/travel_model.dart';
import 'package:absensi_app_new/data/repositories/travel_repository.dart';
import 'package:absensi_app_new/presentation/providers/travel_provider.dart';
import 'package:absensi_app_new/presentation/screens/travel/travel_form_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

Map<String, dynamic> detail() => {
  'tanggal_berangkat': '2026-09-22',
  'tanggal_tujuan': '2026-09-23',
  'tempat_berangkat': 'Kantor',
  'tempat_tujuan': 'Site',
  'waktu_berangkat': '08:00',
  'waktu_tujuan': '09:00',
  'jumlah_hari': 2,
  'lama_hotel': 1,
  'amount_transportasi': '100.25',
  'amount_tunjangan': '50.10',
  'amount_hotel': '200.00',
  'misc': '10.00',
  'amount_other': '5.05',
};
TravelDraft draft({List<TravelEntry>? details}) => TravelDraft(
  companyId: 1,
  description: 'Dinas',
  details: details ?? [TravelEntry(detail())],
);
Map<String, dynamic> row(int id) => {
  'id': id,
  'company_id': 1,
  'keterangan': 'Dinas',
  'jumlah_lampiran': 0,
  'catatan': '',
  'total': '415.50',
  'status': 'Pending Approval',
  'approval_level': 1,
  'can_edit': true,
  'can_cancel': true,
  'details': [detail()],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('exact cents and daily nightly multipliers', () {
    expect(draft().total, 41550);
    expect(draft().validate(), isNull);
    expect(
      draft(details: List.generate(5, (_) => TravelEntry(detail()))).total,
      207750,
    );
    expect(TravelEntry.money('50,10'), 5010);
    expect(TravelEntry.money('1.001'), isNull);
    final payload = draft().toJson();
    expect(payload.containsKey('total'), isFalse);
    expect((payload['details'] as List).first.containsKey('subtotal'), isFalse);
  });
  test('validates entry limits dates times days and costs', () {
    expect(draft(details: []).validate(), isNotNull);
    expect(
      draft(details: List.generate(6, (_) => TravelEntry(detail()))).validate(),
      isNotNull,
    );
    for (final invalid in [
      {'tanggal_tujuan': '2026-09-21'},
      {'tanggal_tujuan': '2026-09-22', 'waktu_tujuan': '07:00'},
      {'waktu_berangkat': '25:00'},
      {'jumlah_hari': 0},
      {'lama_hotel': -1},
      {'amount_hotel': '-1'},
      {'tempat_tujuan': ''},
      {'amount_tunjangan': '999999999.99', 'jumlah_hari': 3650},
    ]) {
      expect(
        draft(
          details: [
            TravelEntry({...detail(), ...invalid}),
          ],
        ).validate(),
        isNotNull,
      );
    }
    expect(
      draft(
        details: [
          TravelEntry({...detail(), 'waktu_berangkat': '', 'waktu_tujuan': ''}),
        ],
      ).validate(),
      isNull,
    );
  });
  test(
    'sends nested JSON for create and edit without derived fields',
    () async {
      final client = ApiClient();
      var calls = 0;
      client.dio.httpClientAdapter = ApiStub((request) {
        expect(request.uri.host, '10.0.2.2');
        expect(request.headers['Host'], 'internal-system.test');
        expect(
          request.path,
          ++calls == 1 ? '/travel-reimbursements' : '/travel-reimbursements/1',
        );
        expect(request.data, draft().toJson());
        return jsonResponse({'data': row(1)});
      });
      final repo = TravelRepository(client);
      await repo.save(draft());
      await repo.save(draft(), id: 1);
      expect(calls, 2);
    },
  );
  test('loads all pages and companies', () async {
    final client = ApiClient();
    final pages = <int>[];
    client.dio.httpClientAdapter = ApiStub((request) {
      if (request.path.endsWith('/companies')) {
        return jsonResponse([
          {'id': 1, 'nama': 'Company'},
        ]);
      }
      final page = request.queryParameters['page'] as int;
      pages.add(page);
      return jsonResponse({
        'data': [row(page)],
        'last_page': 2,
      });
    });
    final repo = TravelRepository(client);
    expect((await repo.getCompanies()).single.name, 'Company');
    expect(await repo.getList(), hasLength(2));
    expect(pages, [1, 2]);
  });
  test('duplicate submits blocked and validation errors retained', () async {
    final client = ApiClient();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = ApiStub((_) => response.future);
    final notifier = TravelNotifier(TravelRepository(client));
    addTearDown(notifier.dispose);
    final pending = notifier.save(draft());
    expect(await notifier.save(draft()), isFalse);
    response.complete(
      jsonResponse({
        'errors': {
          'details.0.jumlah_hari': ['Number of Days tidak valid.'],
        },
      }, status: 422),
    );
    expect(await pending, isFalse);
    expect(notifier.state.submitError, 'Number of Days tidak valid.');
  });
  test('cancel replaces record without removing it', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/travel-reimbursements/1/cancel');
      return jsonResponse({
        'data': {
          ...row(1),
          'status': 'Cancelled',
          'can_edit': false,
          'can_cancel': false,
        },
      });
    });
    final notifier = TravelNotifier(TravelRepository(client));
    addTearDown(notifier.dispose);
    expect(await notifier.cancel(1), isTrue);
    expect(notifier.state.records.single.statusLabel, 'Cancelled');
    expect(notifier.state.records.single.canEdit, isFalse);
  });
  testWidgets('edit retains details and sends corrected cost', (tester) async {
    final client = ApiClient();
    var saved = false;
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/travel-reimbursements/1');
      expect(request.data['details'][0]['amount_transportasi'], '120.50');
      saved = true;
      return jsonResponse({'data': row(1)});
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          travelRepositoryProvider.overrideWithValue(TravelRepository(client)),
          travelCompaniesProvider.overrideWith(
            (ref) async => [const TravelCompany(id: 1, name: 'Company')],
          ),
        ],
        child: MaterialApp(
          home: TravelFormScreen(record: TravelModel.fromJson(row(1))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = find.widgetWithText(TextFormField, 'Transportation');
    await tester.ensureVisible(field);
    await tester.enterText(field, '120,50');
    await tester.ensureVisible(find.text('Save Request'));
    await tester.tap(find.text('Save Request'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('add remove entries preserves remaining input', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          travelCompaniesProvider.overrideWith(
            (ref) async => [const TravelCompany(id: 1, name: 'Company')],
          ),
        ],
        child: MaterialApp(
          home: TravelFormScreen(record: TravelModel.fromJson(row(1))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 4; i++) {
      await tester.ensureVisible(find.text('Add Travel Entry (Maximum 5)'));
      await tester.tap(find.text('Add Travel Entry (Maximum 5)'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Travel Entry 5'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Add Travel Entry (Maximum 5)'),
          )
          .onPressed,
      isNull,
    );
    await tester.ensureVisible(find.byTooltip('Remove travel entry 2'));
    await tester.tap(find.byTooltip('Remove travel entry 2'));
    await tester.pumpAndSettle();
    expect(find.text('Travel Entry 5'), findsNothing);
    expect(find.text('Kantor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
