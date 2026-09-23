import 'package:geolocator/geolocator.dart';

/// A fix used for attendance must be recent and sufficiently accurate.
class AttendanceLocation {
  static const maxAge = Duration(seconds: 30);
  static const maxAccuracyMeters = 50.0;

  static void validate(Position position, {DateTime? now}) {
    final age = (now ?? DateTime.now()).difference(position.timestamp);
    if (age.isNegative || age > maxAge) {
      throw StateError('The GPS location is out of date. Please try again.');
    }
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > maxAccuracyMeters) {
      throw StateError(
        'GPS accuracy must be within 50 meters. '
        'Move to an open area and try again.',
      );
    }
  }
}
