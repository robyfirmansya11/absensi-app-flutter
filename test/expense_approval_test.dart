import 'dart:async';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/repositories/expense_repository.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/providers/expense_provider.dart';
import 'package:absensi_app_new/presentation/screens/expense/expense_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

Map<String, dynamic> approvalRow(int id, {bool actionable = true}) => {
  'id': id,
  'company_id': 1,
  'company_name': 'Company',
  'created_by': 'Direct Report',
  'keterangan': 'Operational advance',
  'jumlah_total': '415.50',

  'status': 'Pending Approval',
  'approval_level': actionable ? 1 : 2,
  'can_edit': false,
  'can_cancel': false,
  'can_approve': actionable,
  'tanggal': '2026-09-23',
  'informasi_transfer': 'Bank transfer',
  'has_attachment': false,
  'jumlah_lampiran': 0,
  'details': [
    {'keterangan': 'Transport', 'jumlah': '200.25'},
    {'keterangan': 'Supplies', 'jumlah': '215.25'},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'approval list paginates and decisions send only required fields',
    () async {
      final client = ApiClient();
      var calls = 0;
      client.dio.httpClientAdapter = ApiStub((request) {
        calls++;
        if (request.method == 'GET') {
          expect(request.path, '/expense-reimbursements/approvals');
          final page = request.queryParameters['page'] as int;
          return jsonResponse({
            'data': [approvalRow(page)],
            'last_page': 2,
          });
        }
        if (request.path.endsWith('/reject')) {
          expect(request.data, {'rejected_note': 'Reason'});
        } else {
          expect(request.path, '/expense-reimbursements/1/approve');
          expect(request.data, isNull);
        }
        return jsonResponse({'data': approvalRow(1, actionable: false)});
      });
      final repo = ExpenseRepository(client);
      expect(await repo.getList(approvals: true), hasLength(2));
      expect((await repo.decide(1)).canApprove, isFalse);
      await repo.decide(1, rejectionReason: ' Reason ');
      expect(calls, 4);
    },
  );

  test(
    'duplicate decision is blocked and logout discards pending result',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final started = Completer<void>();
      final release = Completer<void>();
      var count = 0;
      container.read(apiClientProvider).dio.httpClientAdapter = ApiStub((
        request,
      ) async {
        if (request.path == '/login') {
          return jsonResponse({
            'token': 'token',
            'user': {
              'id': 99,
              'name': 'Manager',
              'email': 'manager@example.test',
              'level': 'Superuser',
            },
          });
        }
        count++;
        started.complete();
        await release.future;
        return jsonResponse({'data': approvalRow(1, actionable: false)});
      });
      await container
          .read(authProvider.notifier)
          .login('manager@example.test', 'password');
      final notifier = container.read(expenseApprovalProvider.notifier);
      final pending = notifier.decide(1);
      await started.future;
      expect(await notifier.decide(1), isFalse);
      container.read(authProvider.notifier).clearSession();
      expect(container.read(expenseApprovalProvider).records, isEmpty);
      release.complete();
      expect(await pending, isFalse);
      expect(count, 1);
    },
  );

  for (final reject in [false, true]) {
    testWidgets(
      'manager can ${reject ? 'reject with required reason' : 'approve after confirmation'}',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        var decided = false;
        container.read(apiClientProvider).dio.httpClientAdapter = ApiStub((
          request,
        ) {
          if (request.path == '/login') {
            return jsonResponse({
              'token': 'test-token',
              'user': {
                'id': 99,
                'name': 'Manager',
                'email': 'manager@example.test',
                'level': 'Superuser',
                'jabatan': 'Manager',
              },
            });
          }
          if (request.method == 'POST') {
            expect(
              request.path,
              '/expense-reimbursements/1/${reject ? 'reject' : 'approve'}',
            );
            if (reject) {
              expect(request.data, {'rejected_note': 'Please clarify'});
            }
            decided = true;
            return jsonResponse({'data': approvalRow(1, actionable: false)});
          }
          expect(request.path, '/expense-reimbursements/approvals');
          return jsonResponse({
            'data': decided ? [] : [approvalRow(1)],
            'last_page': 1,
          });
        });
        await tester.runAsync(
          () => container
              .read(authProvider.notifier)
              .login('manager@example.test', 'password'),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: ExpenseScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pending Approvals'), findsOneWidget);
        expect(find.text('Created By: Direct Report'), findsOneWidget);
        expect(find.textContaining('Amount: Rp 415.50'), findsOneWidget);
        await tester.ensureVisible(find.text('Expense Details'));
        await tester.tap(find.text('Expense Details'));
        await tester.pumpAndSettle();
        expect(find.text('Transport'), findsOneWidget);
        expect(find.text('Rp 215.25'), findsOneWidget);
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(reject ? 'Reject' : 'Approve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(reject ? 'Reject' : 'Approve'));
        await tester.pumpAndSettle();
        expect(decided, isFalse);
        final confirm = find.text(
          reject ? 'Confirm Rejection' : 'Confirm Approval',
        );
        if (reject) {
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text('Enter a reason for rejection.'), findsOneWidget);
          expect(decided, isFalse);
          await tester.enterText(find.byType(TextFormField), 'Please clarify');
        }
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(decided, isTrue);
        expect(
          find.text('No requests awaiting your approval.'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
