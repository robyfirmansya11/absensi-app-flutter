import 'package:absensi_app_new/core/network/api_client.dart';
import 'package:absensi_app_new/presentation/providers/auth_provider.dart';
import 'package:absensi_app_new/presentation/screens/attendance/history_screen.dart';
import 'package:absensi_app_new/presentation/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/api_stub.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets('history failure shows retry and can recover', (tester) async {
    final client = ApiClient();
    var fail = true;
    client.dio.httpClientAdapter = ApiStub(
      (_) => fail
          ? jsonResponse({'message': 'Server sedang bermasalah'}, status: 503)
          : jsonResponse({'data': []}),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server sedang bermasalah'), findsOneWidget);
    expect(find.text('No attendance records found'), findsNothing);
    fail = false;
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(find.text('No attendance records found'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
  });
  testWidgets('splash keeps session on server failure and offers retry', (
    tester,
  ) async {
    final client = ApiClient();
    await client.saveToken('valid');
    var attempts = 0;
    client.dio.httpClientAdapter = ApiStub((_) {
      attempts++;
      return jsonResponse({}, status: 503);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [apiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Try Again'), findsOneWidget);
    expect(await client.getToken(), 'valid');
    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.byType(SplashScreen), findsOneWidget);
  });
}
