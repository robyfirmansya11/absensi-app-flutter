import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/screens/splash_screen.dart';

// Global navigator key — dipakai untuk navigate dari luar widget tree
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InSys - Internal System',
      locale: const Locale('en', 'US'),
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // ← tambah ini
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const SplashScreen(),
    );
  }
}
