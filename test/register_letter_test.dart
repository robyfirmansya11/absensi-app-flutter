import 'dart:async';
import 'dart:typed_data';
import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/data/models/register_letter_model.dart';
import 'package:absensi_app_new/data/repositories/register_letter_repository.dart';
import 'package:absensi_app_new/presentation/providers/register_letter_provider.dart';
import 'package:absensi_app_new/presentation/screens/register_letter/register_letter_form_screen.dart';
import 'package:absensi_app_new/presentation/screens/register_letter/register_letter_screen.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

RegisterLetterDraft draft({
  bool existing = false,
  String number = '001/TEST',
  PlatformFile? file,
}) => RegisterLetterDraft(
  companyId: 1,
  date: DateTime(2026, 9, 22),
  number: number,
  recipient: 'Recipient',
  hasExistingAttachment: existing,
  attachment: file,
);
PlatformFile attachment() => PlatformFile(
  name: 'letter.pdf',
  size: 3,
  bytes: Uint8List.fromList([1, 2, 3]),
);
Map<String, dynamic> row(int id, {bool own = true}) => {
  'id': id,
  'company_id': 1,
  'no_surat': '00$id/TEST',
  'ditujukan': 'Recipient $id',
  'tanggal_surat': '2026-09-22',
  'company_name': 'Company',
  'created_by': 'Creator',
  'has_attachment': true,
  'can_edit': own,
  'can_delete': own,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test(
    'requires attachment for new letters, preserves existing upload on edit',
    () {
      expect(draft().validate(), isNotNull);
      expect(draft(existing: true).validate(), isNull);
      expect(draft(file: attachment()).validate(), isNull);
      expect(draft(existing: true, number: ' ').validate(), isNotNull);
      expect(
        draft(
          file: PlatformFile(
            name: 'large.pdf',
            size: RegisterLetterDraft.maxFileBytes + 1,
            path: '/large',
          ),
        ).validate(),
        isNotNull,
      );
      expect(
        draft(
          file: PlatformFile(name: 'bad.exe', size: 1, bytes: Uint8List(1)),
        ).validate(),
        isNotNull,
      );
    },
  );
  test(
    'multipart create and edit use proper fields and preserve attachment',
    () async {
      final client = ApiClient();
      var calls = 0;
      client.dio.httpClientAdapter = ApiStub((request) {
        final form = request.data as FormData;
        final fields = Map.fromEntries(form.fields);
        expect(fields['no_surat'], '001/TEST');
        expect(fields.containsKey('user_id'), isFalse);
        expect(fields.containsKey('department_id'), isFalse);
        expect(request.uri.host, '10.0.2.2');
        expect(request.headers['Host'], 'internal-system.test');
        if (++calls == 1) {
          expect(request.path, '/register-letters');
          expect(form.files.single.key, 'lampiran_surat');
          expect(form.files.single.value.filename, 'letter.pdf');
        } else {
          expect(request.path, '/register-letters/1');
          expect(form.files, isEmpty);
        }
        return jsonResponse({'data': row(1)});
      });
      final repo = RegisterLetterRepository(client);
      await repo.save(draft(file: attachment()));
      await repo.save(draft(existing: true), id: 1);
      expect(calls, 2);
    },
  );
  test('loads all pages and company options', () async {
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
    final repo = RegisterLetterRepository(client);
    expect((await repo.getCompanies()).single.name, 'Company');
    expect(await repo.getList(), hasLength(2));
    expect(pages, [1, 2]);
  });
  test(
    'duplicate submit is blocked and validation errors are visible',
    () async {
      final response = Completer<ResponseBody>();
      final client = ApiClient();
      client.dio.httpClientAdapter = ApiStub((_) => response.future);
      final notifier = RegisterLetterNotifier(RegisterLetterRepository(client));
      addTearDown(notifier.dispose);
      final pending = notifier.save(draft(file: attachment()));
      expect(await notifier.save(draft(file: attachment())), isFalse);
      response.complete(
        jsonResponse({
          'errors': {
            'no_surat': ['Letter Number sudah digunakan.'],
          },
        }, status: 422),
      );
      expect(await pending, isFalse);
      expect(notifier.state.submitError, 'Letter Number sudah digunakan.');
    },
  );
  testWidgets(
    'list searches, hides unauthorized actions and confirms deletion',
    (tester) async {
      final client = ApiClient();
      var deleted = false;
      client.dio.httpClientAdapter = ApiStub((request) {
        if (request.method == 'DELETE') {
          deleted = true;
          return jsonResponse({'message': 'Deleted'});
        }
        return jsonResponse({
          'data': [row(1), row(2, own: false)],
          'last_page': 1,
        });
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            registerLetterRepositoryProvider.overrideWithValue(
              RegisterLetterRepository(client),
            ),
          ],
          child: const MaterialApp(home: RegisterLetterScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Recipient 2');
      await tester.pump();
      expect(find.text('001/TEST'), findsNothing);
      expect(find.text('002/TEST'), findsOneWidget);
      expect(find.text('Delete'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.pump();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isFalse);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(deleted, isTrue);
      expect(find.text('001/TEST'), findsNothing);
    },
  );
  testWidgets('edit preloads fields and saves without reuploading', (
    tester,
  ) async {
    final client = ApiClient();
    var saved = false;
    client.dio.httpClientAdapter = ApiStub((request) {
      expect(request.path, '/register-letters/1');
      final form = request.data as FormData;
      expect(form.files, isEmpty);
      expect(Map.fromEntries(form.fields)['ditujukan'], 'Changed');
      saved = true;
      return jsonResponse({'data': row(1)});
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          registerLetterRepositoryProvider.overrideWithValue(
            RegisterLetterRepository(client),
          ),
          registerLetterCompaniesProvider.overrideWith(
            (ref) async => [
              const RegisterLetterCompany(id: 1, name: 'Company'),
            ],
          ),
        ],
        child: MaterialApp(
          home: RegisterLetterFormScreen(
            record: RegisterLetterModel.fromJson(row(1)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('001/TEST'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('recipient')), 'Changed');
    await tester.ensureVisible(find.text('Save Letter'));
    await tester.tap(find.text('Save Letter'));
    await tester.pumpAndSettle();
    expect(saved, isTrue);
    expect(tester.takeException(), isNull);
  });
}
