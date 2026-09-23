import 'dart:async';
import 'dart:typed_data';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/payment_model.dart';
import 'package:absensi_app_new/data/repositories/payment_repository.dart';
import 'package:absensi_app_new/presentation/providers/payment_provider.dart';
import 'package:absensi_app_new/presentation/screens/payment/create_payment_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

PaymentDraft draft({
  int amount = 10000000,
  int withholding = 200000,
  DateTime? due,
  PlatformFile? file,
}) => PaymentDraft(
  companyId: 1,
  invoice: ' INV-001 ',
  customer: 'Supplier',
  billingDate: DateTime(2026, 9, 20),
  dueDate: due ?? DateTime(2026, 9, 30),
  amountMinor: amount,
  withholdingMinor: withholding,
  adminMinor: 250000,
  attachment:
      file ??
      PlatformFile(
        name: 'invoice.pdf',
        size: 3,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
);
Map<String, dynamic> row(int id) => {
  'id': id,
  'no_invoice': 'INV-001',
  'status': 'Pending Approval',
  'approval_level': 2,
  'can_cancel': true,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('money parsing and rounded preview match backend', () {
    expect(PaymentDraft.parseMoney('100,50'), 10050);
    expect(PaymentDraft.parseMoney('1.000.000'), isNull);
    expect(PaymentDraft.parseMoney('-1'), isNull);
    expect(PaymentDraft.parseMoney('1.234'), isNull);
    expect(draft().vat, 11000);
    expect(draft().total, 111500);
    expect(PaymentDraft.totalFor(10050, 1, 1), 112);
    expect(draft().toJson()['jumlah'], '100000.00');
    expect(draft().toJson()['no_invoice'], 'INV-001');
  });

  test('rejects invalid dates, amounts and attachments', () {
    expect(draft().validate(), isNull);
    expect(draft(due: DateTime(2026, 9, 19)).validate(), isNotNull);
    expect(draft(amount: 0).validate(), isNotNull);
    expect(draft(withholding: 999999999).validate(), isNotNull);
    for (final file in [
      PlatformFile(name: 'empty.pdf', size: 0, bytes: Uint8List(0)),
      PlatformFile(
        name: 'large.pdf',
        size: PaymentDraft.maxFileBytes + 1,
        path: '/large.pdf',
      ),
      PlatformFile(name: 'script.php', size: 1, bytes: Uint8List(1)),
      PlatformFile(name: 'missing.pdf', size: 1),
    ]) {
      expect(draft(file: file).validate(), isNotNull);
    }
  });

  test(
    'uploads multipart with attachment and no client-owned approval fields',
    () async {
      final client = ApiClient();
      client.dio.httpClientAdapter = ApiStub((request) {
        expect(request.path, '/payment-applications');
        expect(request.uri.host, '10.0.2.2');
        expect(request.headers['Host'], 'internal-system.test');
        final body = request.data as FormData;
        final fields = Map.fromEntries(body.fields);
        expect(fields['jumlah'], '100000.00');
        for (final key in [
          'status',
          'user_id',
          'ppn',
          'jumlah_total',
          'approved_by',
        ]) {
          expect(fields.containsKey(key), isFalse);
        }
        expect(body.files.single.key, 'lampiran');
        expect(body.files.single.value.filename, 'invoice.pdf');
        expect(body.files.single.value.length, 3);
        return jsonResponse({'data': row(1)}, status: 201);
      });
      expect((await PaymentRepository(client).create(draft())).id, 1);
    },
  );

  test('loads company options and every page', () async {
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
    final repo = PaymentRepository(client);
    expect((await repo.getCompanies()).single.name, 'Company');
    expect(await repo.getList(), hasLength(2));
    expect(pages, [1, 2]);
  });

  test('duplicate submit blocked and server validation displayed', () async {
    final client = ApiClient();
    final response = Completer<ResponseBody>();
    client.dio.httpClientAdapter = ApiStub((_) => response.future);
    final notifier = PaymentNotifier(PaymentRepository(client));
    addTearDown(notifier.dispose);
    final result = notifier.create(draft());
    expect(await notifier.create(draft()), isFalse);
    response.complete(
      jsonResponse({
        'errors': {
          'lampiran': ['Lampiran tidak valid.'],
        },
      }, status: 422),
    );
    expect(await result, isFalse);
    expect(notifier.state.submitError, 'Lampiran tidak valid.');
    expect(notifier.state.isSubmitting, isFalse);
  });

  test('cancellation replaces record and paid status is readable', () async {
    final client = ApiClient();
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/payment-applications/1/cancel');
      return jsonResponse({
        'data': {...row(1), 'status': 'Cancelled', 'can_cancel': false},
      });
    });
    final notifier = PaymentNotifier(PaymentRepository(client));
    addTearDown(notifier.dispose);
    expect(await notifier.cancel(1), isTrue);
    expect(notifier.state.records.single.canCancel, isFalse);
    expect(notifier.state.records.single.statusLabel, 'Cancelled');
    expect(
      PaymentModel.fromJson({...row(2), 'status': 'Paid'}).statusLabel,
      'Paid',
    );
  });

  testWidgets('company loading can retry and form shows invoice validation', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          paymentCompaniesProvider.overrideWith((ref) async {
            if (++attempts == 1) throw Exception('offline');
            return [const PaymentCompany(id: 1, name: 'Company')];
          }),
        ],
        child: const MaterialApp(home: CreatePaymentScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Daftar perusahaan gagal'), findsNothing);
    await tester.ensureVisible(find.text('Submit Request'));
    await tester.tap(find.text('Submit Request'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('invoice')));
    expect(find.text('Invoice Number is required.'), findsOneWidget);
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });
}
