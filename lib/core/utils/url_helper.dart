class UrlHelper {
  /// Ganti domain .test dengan IP yang bisa diakses emulator Android.
  /// internal-system.test → 10.0.2.2
  static String fixUrl(String url) {
    return url.replaceFirst('internal-system.test', '10.0.2.2');
  }
}
