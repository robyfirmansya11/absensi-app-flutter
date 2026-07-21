enum AppEnvironment { development, production }

class AppConfig {
  // Ganti ke production saat mau build APK untuk production
  static const AppEnvironment environment = AppEnvironment.development;

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isProduction => environment == AppEnvironment.production;

  // Base URL otomatis sesuai environment
  static String get baseUrl {
    switch (environment) {
      case AppEnvironment.development:
        return 'http://10.0.2.2/api/v1';
      case AppEnvironment.production:
        return 'http://202.57.3.188/api/v1';
    }
  }

  // Host header — hanya dibutuhkan di development (Herd)
  static String? get hostHeader {
    switch (environment) {
      case AppEnvironment.development:
        return 'internal-system.test';
      case AppEnvironment.production:
        return null; // tidak perlu di production
    }
  }

  // URL fixer untuk foto
  static String fixImageUrl(String url) {
    switch (environment) {
      case AppEnvironment.development:
        return url.replaceFirst('internal-system.test', '10.0.2.2');
      case AppEnvironment.production:
        return url.replaceFirst('internal-system.test', '202.57.3.188');
    }
  }
}
