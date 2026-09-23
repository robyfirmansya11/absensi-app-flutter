import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/connectivity_service.dart';

/// Provider untuk status koneksi internet (true = online, false = offline).
final connectivityProvider = StreamProvider<bool>((ref) {
  return ConnectivityService.onConnectivityChanged;
});

/// Provider untuk cek koneksi sekali (tidak stream).
final isConnectedProvider = FutureProvider<bool>((ref) async {
  return ConnectivityService.isConnected();
});
