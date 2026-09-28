import 'dart:async';
import 'dart:typed_data';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/meal_model.dart';
import 'package:absensi_app_new/data/repositories/meal_repository.dart';
import 'package:absensi_app_new/presentation/providers/meal_provider.dart';
import 'package:absensi_app_new/presentation/screens/meal/meal_form_screen.dart';
import 'package:absensi_app_new/presentation/screens/meal/meal_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

Map<String, dynamic> mealRow(int id) => {
  'id': id,
  'company_id': 1,
  'claim_date': '2026-09-26',
  'company_name': 'Company',
  'created_by': 'Employee',
  'total_amount': '123.45',
  'receipt_count': 1,
  'status': 'Submitted',
  'can_edit': true,
  'actions': ['cancel'],
  'items': [
    {
      'id': 10,
      'meal_date': '2026-09-25',
      'meal_type': 'Lunch',
      'amount': '123.45',
      'merchant': 'Cafe',
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  MealDraft draft({PlatformFile? file, int? id, int count = 1}) => MealDraft(
    companyId: 1,
    date: DateTime(2026, 9, 26),
    items: List.generate(
      count,
      (_) => MealItemDraft(
        id: id,
        date: DateTime(2026, 9, 25),
        type: 'Lunch',
        amountMinor: 12345,
        receipt: file,
      ),
    ),
  );
  test('receipt validation requires new images but retains existing ones', () {
    expect(draft().validate(), isNotNull);
    expect(draft(id: 10).validate(), isNull);
    expect(draft(id: 10, count: 21).validate(), isNotNull);
    expect(
      draft(
        file: PlatformFile(name: 'file.pdf', size: 1, bytes: Uint8List(1)),
      ).validate(),
      isNotNull,
    );
    expect(
      draft(
        file: PlatformFile(
          name: 'file.jpg',
          size: 5242881,
          bytes: Uint8List(1),
        ),
      ).validate(),
      isNotNull,
    );
    expect(
      draft(
        file: PlatformFile(name: 'file.png', size: 1, bytes: Uint8List(1)),
      ).total,
      12345,
    );
  });
  test(
    'multipart uses receipt fields and keeps existing receipt IDs',
    () async {
      final client = ApiClient();
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (r, h) {
            final form = r.data as FormData;
            final fields = Map.fromEntries(form.fields);
            expect(fields['items[0][amount]'], '123.45');
            expect(fields['items[0][id]'], '10');
            expect(fields.containsKey('status'), isFalse);
            expect(form.files, isEmpty);
            h.next(r);
          },
        ),
      );
      client.dio.httpClientAdapter = ApiStub(
        (r) => jsonResponse({'data': mealRow(1)}),
      );
      await MealRepository(client).save(draft(id: 10), id: 1);
    },
  );
  test('review pagination and actions use expected routes and notes', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub((r) {
      if (r.method == 'GET') {
        expect(r.path, '/meal-claims');
        expect(r.queryParameters['review'], 1);
        return jsonResponse({
          'data': [mealRow(r.queryParameters['page'])],
          'last_page': 2,
        });
      }
      expect(r.path, '/meal-claims/1/return');
      expect(r.data, {'note': 'Correct receipt'});
      return jsonResponse({'data': mealRow(1)});
    });
    final repo = MealRepository(client);
    expect(await repo.getList(approvals: true), hasLength(2));
    await repo.act(1, 'return', note: ' Correct receipt ');
  });
  test(
    'duplicate action is blocked and disposed provider ignores response',
    () async {
      final client = ApiClient();
      final gate = Completer<void>();
      var calls = 0;
      client.dio.httpClientAdapter = ApiStub((r) async {
        calls++;
        await gate.future;
        return jsonResponse({'data': mealRow(1)});
      });
      final notifier = MealNotifier(MealRepository(client));
      final pending = notifier.act(1, 'cancel');
      expect(await notifier.act(1, 'cancel'), isFalse);
      notifier.dispose();
      gate.complete();
      expect(await pending, isFalse);
      expect(calls, 1);
    },
  );
  testWidgets('edit retains receipt and saves existing item without reupload', (
    tester,
  ) async {
    final client = ApiClient();
    var saved = false;
    client.dio.httpClientAdapter = ApiStub((r) {
      if (r.path.endsWith('companies')) {
        return jsonResponse([
          {'id': 1, 'nama': 'Company'},
        ]);
      }
      saved = true;
      expect(
        Map.fromEntries((r.data as FormData).fields)['items[0][id]'],
        '10',
      );
      return jsonResponse({'data': mealRow(1)});
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(MealRepository(client)),
        ],
        child: MaterialApp(
          home: MealFormScreen(record: MealModel.fromJson(mealRow(1))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Existing receipt photo will be retained.'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save and Submit'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
  });
  testWidgets('list exposes allowed actions and cancellation confirmation', (
    tester,
  ) async {
    final client = ApiClient();
    var cancelled = false;
    client.dio.httpClientAdapter = ApiStub((r) {
      if (r.method == 'GET') {
        return jsonResponse({
          'data': [mealRow(1)],
          'last_page': 1,
        });
      }
      cancelled = true;
      return jsonResponse({
        'data': mealRow(1)
          ..['actions'] = []
          ..['status'] = 'Cancelled',
      });
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(MealRepository(client)),
        ],
        child: const MaterialApp(home: MealScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meal Claim #1 · Submitted'));
    await tester.pumpAndSettle();
    expect(find.text('Approve'), findsNothing);
    await tester.ensureVisible(find.text('Cancel Claim'));
    await tester.tap(find.text('Cancel Claim'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
    await tester.tap(find.text('Cancel Claim').last);
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}
