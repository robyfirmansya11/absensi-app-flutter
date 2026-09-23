import 'dart:async';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/providers/cuti_approval_provider.dart';
import 'package:absensi_app_new/presentation/screens/cuti/cuti_screen.dart';
import 'package:absensi_app_new/presentation/screens/cuti/cuti_approval_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

Map<String, dynamic> pendingLeave({bool allowed = true}) => {
  ...leaveRow(1),
  'status': 'Pending Approval',
  'employee_name': 'Direct Report',
  'can_approve': allowed,
  'can_reject': allowed,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test(
    'duplicate decisions blocked and processed item stays removed if reload fails',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final started = Completer<void>();
      final finish = Completer<void>();
      var reload = false;
      var calls = 0;
      container.read(apiClientProvider).dio.httpClientAdapter = ApiStub((
        request,
      ) async {
        if (request.method == 'GET') {
          return reload
              ? jsonResponse({'message': 'Reload failed'}, status: 503)
              : jsonResponse([pendingLeave()]);
        }
        calls++;
        started.complete();
        await finish.future;
        reload = true;
        return jsonResponse({'message': 'Approved'});
      });
      final notifier = container.read(cutiApprovalProvider.notifier);
      await notifier.loadAll();
      final decision = notifier.approve(1);
      await started.future;
      expect(await notifier.reject(1, 'Reason'), isFalse);
      finish.complete();
      expect(await decision, isTrue);
      expect(calls, 1);
      expect(container.read(cutiApprovalProvider).list, isEmpty);
      expect(
        container.read(cutiApprovalProvider).errorMessage,
        'Reload failed',
      );
    },
  );

  testWidgets(
    'load failure is visible and retry works with read-only permissions',
    (tester) async {
      final client = ApiClient();
      var fail = true;
      client.dio.httpClientAdapter = ApiStub(
        (request) => fail
            ? jsonResponse({'message': 'Connection failed'}, status: 503)
            : jsonResponse([pendingLeave(allowed: false)]),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(home: CutiApprovalScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('No requests awaiting your approval.'), findsNothing);
      fail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();
      expect(find.text('Direct Report'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    },
  );

  for (final reject in [false, true]) {
    testWidgets(
      'Leave Requests manager ${reject ? 'rejects with reason' : 'approves after confirmation'}',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        var decided = false;
        container.read(apiClientProvider).dio.httpClientAdapter = ApiStub((
          request,
        ) {
          if (request.path == '/login') {
            return jsonResponse({
              'token': 'token',
              'user': {
                'id': 9,
                'name': 'Manager',
                'email': 'm@example.test',
                'level': 'Superuser',
                'jabatan': 'Manager',
              },
            });
          }
          if (request.path == '/cuti/quota') {
            return jsonResponse({
              'tahun': 2026,
              'kuota_tahunan': 12,
              'cuti_terpakai': 0,
              'sisa_cuti': 12,
            });
          }
          if (request.path == '/cuti') return jsonResponse([]);
          if (request.method == 'POST') {
            expect(request.path, '/cuti/1/${reject ? 'reject' : 'approve'}');
            if (reject) {
              expect(request.data, {'rejected_note': 'Please reschedule'});
            }
            decided = true;
            return jsonResponse({'message': 'Processed'});
          }
          return jsonResponse(decided ? [] : [pendingLeave()]);
        });
        await tester.runAsync(
          () => container
              .read(authProvider.notifier)
              .login('m@example.test', 'password'),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: CutiScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Pending Approvals'), findsOneWidget);
        expect(find.text('Awaiting Manager Approval'), findsOneWidget);
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
          await tester.enterText(
            find.byType(TextFormField),
            'Please reschedule',
          );
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
