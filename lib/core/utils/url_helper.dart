// SESUDAH — benar, naik satu level lalu masuk ke constants/
import '../constants/app_config.dart';

class UrlHelper {
  /// Fix URL foto sesuai environment aktif.
  static String fixUrl(String url) {
    return AppConfig.fixImageUrl(url);
  }
}
