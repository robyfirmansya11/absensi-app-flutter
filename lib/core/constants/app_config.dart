enum AppEnvironment { development, production }

class AppConfig {
  static const AppEnvironment environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'development') ==
          'production'
      ? AppEnvironment.production
      : AppEnvironment.development;

  static bool get isDevelopment => environment == AppEnvironment.development;
  static bool get isProduction => environment == AppEnvironment.production;

  static String get baseUrl {
    switch (environment) {
      case AppEnvironment.development:
        return 'http://10.0.2.2/api/v1';
      case AppEnvironment.production:
        return 'https://insys.bumimorowaliutama.com/api/v1';
    }
  }

  static String? get hostHeader {
    switch (environment) {
      case AppEnvironment.development:
        return 'internal-system.test';
      case AppEnvironment.production:
        return null;
    }
  }

  static String fixImageUrl(String url) {
    switch (environment) {
      case AppEnvironment.development:
        return url.replaceFirst('internal-system.test', '10.0.2.2');
      case AppEnvironment.production:
        return url
            .replaceFirst(
              'http://internal-system.test',
              'https://insys.bumimorowaliutama.com',
            )
            .replaceFirst(
              'http://192.168.3.10/insys',
              'https://insys.bumimorowaliutama.com',
            )
            .replaceFirst('http://', 'https://');
    }
  }
}
