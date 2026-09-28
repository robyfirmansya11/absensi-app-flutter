import 'dart:math' as math;
import '../../data/models/attendance_model.dart';
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

/// Uses the same rounded Haversine distance and nearest-site rule as the API.
class AttendanceOfficeMatch {
  final OfficeLocationModel office;
  final int distance;
  const AttendanceOfficeMatch(this.office, this.distance);
  bool get isOutsideRadius => distance > office.radius;

  static AttendanceOfficeMatch? nearest(
    List<OfficeLocationModel> offices,
    double latitude,
    double longitude,
  ) {
    AttendanceOfficeMatch? result;
    for (final office in offices) {
      final latDelta = (latitude - office.latitude) * math.pi / 180;
      final lngDelta = (longitude - office.longitude) * math.pi / 180;
      final a =
          math.pow(math.sin(latDelta / 2), 2) +
          math.cos(office.latitude * math.pi / 180) *
              math.cos(latitude * math.pi / 180) *
              math.pow(math.sin(lngDelta / 2), 2);
      final clamped = a.clamp(0.0, 1.0);
      final distance =
          (6371000 * 2 * math.atan2(math.sqrt(clamped), math.sqrt(1 - clamped)))
              .round();
      if (result == null || distance < result.distance) {
        result = AttendanceOfficeMatch(office, distance);
      }
    }
    return result;
  }
}
