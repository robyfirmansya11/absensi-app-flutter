import 'dart:async';
import 'dart:typed_data';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/loan_model.dart';
import 'package:absensi_app_new/data/repositories/loan_repository.dart';
import 'package:absensi_app_new/presentation/providers/loan_provider.dart';
import 'package:absensi_app_new/presentation/screens/loan/loan_form_screen.dart';
import 'package:absensi_app_new/presentation/screens/loan/loan_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

LoanDraft draft({int amount = 150050, PlatformFile? file}) => LoanDraft(
  companyId: 1,
  date: DateTime(2026, 9, 22),
  amountMinor: amount,
  attachment: file,
);
Map<String, dynamic> row(int id) => {
  'id': id,
  'company_id': 1,
  'tanggal': '2026-09-22',
  'jumlah_dana': '1500.50',
  'terbilang': 'One Thousand Five Hundred Rupiah and Fifty Sen',
  'company_name': 'Company',
  'status': 'Pending Approval',
  'approval_level': 2,
  'can_edit': true,
  'can_cancel': true,
  'has_attachment': false,
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('decimal amounts and optional attachments validated', () {
    expect(LoanDraft.parseMoney('1500,50'), 150050);
    expect(LoanDraft.parseMoney('1.000.000'), isNull);
    expect(LoanDraft.parseMoney('1e3'), isNull);
    expect(LoanDraft.parseMoney('1.001'), isNull);
    expect(draft().validate(), isNull);
    expect(draft(amount: 0).validate(), isNotNull);
    expect(draft(amount: 100000000000000).validate(), isNotNull);
    expect(
      draft(
        file: PlatformFile(name: 'bad.php', size: 1, bytes: Uint8List(1)),
      ).validate(),
      isNotNull,
    );
    expect(
      draft(
        file: PlatformFile(
          name: 'large.pdf',
          size: LoanDraft.maxFileBytes + 1,
          path: '/large',
        ),
      ).validate(),
      isNotNull,
    );
    expect(draft().toJson()['jumlah_dana'], '1500.50');
  });
  test(
    'multipart create and edit leave derived and ownership fields to server',
    () async {
      final client = ApiClient();
      var calls = 0;
      client.dio.httpClientAdapter = ApiStub((request) {
        final form = request.data as FormData;
        final fields = Map.fromEntries(form.fields);
        expect(fields['jumlah_dana'], '1500.50');
        for (final key in [
          'status',
          'approval_level',
          'user_id',
          'department_id',
          'terbilang',
        ]) {
          expect(fields.containsKey(key), isFalse);
        }
        expect(request.uri.host, '10.0.2.2');
        expect(request.headers['Host'], 'internal-system.test');
        if (++calls == 1) {
          expect(request.path, '/loan-notes');
          expect(form.files.single.key, 'lampiran');
        } else {
          expect(request.path, '/loan-notes/1');
          expect(form.files, isEmpty);
        }
        return jsonResponse({'data': row(1)});
      });
      final repo = LoanRepository(client);
      await repo.save(
        draft(
          file: PlatformFile(name: 'loan.pdf', size: 3, bytes: Uint8List(3)),
        ),
      );
      await repo.save(draft(), id: 1);
      expect(calls, 2);
    },
  );
  test('pagination and company options', () async {
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
    final repo = LoanRepository(client);
    expect((await repo.getCompanies()).single.name, 'Company');
    expect(await repo.getList(), hasLength(2));
    expect(pages, [1, 2]);
  });
  test('duplicate submit blocked and validation errors preserved', () async {
    final client = ApiClient();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = ApiStub((_) => response.future);
    final notifier = LoanNotifier(LoanRepository(client));
    addTearDown(notifier.dispose);
    final pending = notifier.save(draft());
    expect(await notifier.save(draft()), isFalse);
    response.complete(
      jsonResponse({
        'errors': {
          'jumlah_dana': ['Enter a valid amount.'],
        },
      }, status: 422),
    );
    expect(await pending, isFalse);
    expect(notifier.state.submitError, 'Enter a valid amount.');
  });
  test('status distinguishes supervisor and finance approval', () {
    expect(
      LoanModel.fromJson(row(1)).statusLabel,
      'Awaiting Finance Manager Approval',
    );
    expect(
      LoanModel.fromJson({...row(1), 'approval_level': 1}).statusLabel,
      'Awaiting Supervisor Approval',
    );
  });
  testWidgets('cancellation keeps audit record and hides edit actions', (
    tester,
  ) async {
    final client = ApiClient();
    var cancelled = false;
    client.dio.httpClientAdapter = ApiStub((request) {
      if (request.path.endsWith('/cancel')) {
        cancelled = true;
        return jsonResponse({
          'data': {
            ...row(1),
            'status': 'Cancelled',
            'can_edit': false,
            'can_cancel': false,
          },
        });
      }
      return jsonResponse({
        'data': [row(1)],
        'last_page': 1,
      });
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanRepositoryProvider.overrideWithValue(LoanRepository(client)),
        ],
        child: const MaterialApp(home: LoanScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Cancel'));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(cancelled, isFalse);
    await tester.tap(find.widgetWithText(FilledButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(cancelled, isTrue);
    expect(find.text('Loan #1'), findsOneWidget);
    expect(find.text('Status: Cancelled'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
  });
  testWidgets('edit amount without uploading a file', (tester) async {
    final client = ApiClient();
    var saved = false;
    client.dio.httpClientAdapter = ApiStub((request) {
      final form = request.data as FormData;
      expect(form.files, isEmpty);
      expect(Map.fromEntries(form.fields)['jumlah_dana'], '2000.25');
      saved = true;
      return jsonResponse({'data': row(1)});
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          loanRepositoryProvider.overrideWithValue(LoanRepository(client)),
          loanCompaniesProvider.overrideWith(
            (ref) async => [const LoanCompany(id: 1, name: 'Company')],
          ),
        ],
        child: MaterialApp(
          home: LoanFormScreen(record: LoanModel.fromJson(row(1))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('amount')), '2000,25');
    await tester.ensureVisible(find.text('Save Request'));
    await tester.tap(find.text('Save Request'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });
}
