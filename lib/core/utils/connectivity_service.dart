import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  /// Cek apakah ada koneksi internet saat ini.
  static Future<bool> isConnected() async {
    final result = await _connectivity.checkConnectivity();
    return _isConnectedFromResult(result);
  }

  /// Stream perubahan koneksi — listen untuk update real-time.
  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
      (result) => _isConnectedFromResult(result),
    );
  }

  static bool _isConnectedFromResult(List<ConnectivityResult> result) {
    return result.any(
      (r) =>
          r == ConnectivityResult.mobile ||
          r == ConnectivityResult.wifi ||
          r == ConnectivityResult.ethernet,
    );
  }
}
