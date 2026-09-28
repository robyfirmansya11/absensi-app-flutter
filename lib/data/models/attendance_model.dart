import '../../core/utils/english_ui.dart';

class AttendanceTodayModel {
  final String date;
  final bool hasClockedIn;
  final bool hasClockedOut;
  final bool isOutsideRadius;
  final String? clockIn;
  final String? clockOut;
  final String? status;
  final String? clockInPhoto;
  final String? Note;
  final String? clockInLocationReason;
  final String? clockOutLocationReason;
  final OfficeLocationModel? clockInOfficeLocation;
  final OfficeLocationModel? clockOutOfficeLocation;

  AttendanceTodayModel({
    this.isOutsideRadius = false,
    required this.date,
    required this.hasClockedIn,
    required this.hasClockedOut,
    this.clockIn,
    this.clockOut,
    this.status,
    this.clockInPhoto,
    this.Note,
    this.clockInLocationReason,
    this.clockOutLocationReason,
    this.clockInOfficeLocation,
    this.clockOutOfficeLocation,
  });

  factory AttendanceTodayModel.fromJson(Map<String, dynamic> json) {
    return AttendanceTodayModel(
      date: json['date'] as String,
      hasClockedIn: json['has_clocked_in'] as bool,
      hasClockedOut: json['has_clocked_out'] as bool,
      clockIn: json['clock_in'] as String?,
      clockOut: json['clock_out'] as String?,
      status: json['status'] as String?,
      clockInPhoto: json['clock_in_photo'] as String?,
      Note: json['note'] as String?,
      isOutsideRadius: json['is_outside_radius'] as bool? ?? false,
      clockInLocationReason: json['clock_in_location_reason'] as String?,
      clockOutLocationReason: json['clock_out_location_reason'] as String?,
      clockInOfficeLocation: json['clock_in_office_location'] == null
          ? null
          : OfficeLocationModel.fromJson(
              Map<String, dynamic>.from(json['clock_in_office_location']),
            ),
      clockOutOfficeLocation: json['clock_out_office_location'] == null
          ? null
          : OfficeLocationModel.fromJson(
              Map<String, dynamic>.from(json['clock_out_office_location']),
            ),
    );
  }
}

class AttendanceHistoryModel {
  final int id;
  final String date;
  final String formattedDate;
  final String? clockIn;
  final String? clockOut;
  final String? status;
  final String? clockInPhoto;
  final String? clockOutPhoto;
  final String? clockInAddress;
  final String? clockOutAddress;
  final String? note;
  final bool isOutsideRadius;
  final String? clockInLocationReason;
  final String? clockOutLocationReason;
  final OfficeLocationModel? clockInOfficeLocation;
  final OfficeLocationModel? clockOutOfficeLocation;

  AttendanceHistoryModel({
    required this.id,
    required this.date,
    required this.formattedDate,
    this.clockIn,
    this.clockOut,
    this.status,
    this.clockInPhoto,
    this.clockOutPhoto,
    this.clockInAddress,
    this.clockOutAddress,
    this.note,
    this.isOutsideRadius = false,
    this.clockInLocationReason,
    this.clockOutLocationReason,
    this.clockInOfficeLocation,
    this.clockOutOfficeLocation,
  });

  factory AttendanceHistoryModel.fromJson(Map<String, dynamic> json) {
    return AttendanceHistoryModel(
      id: json['id'],
      date: json['date'],
      formattedDate: EnglishUi.date(json['date']?.toString() ?? ''),
      clockIn: json['clock_in'],
      clockOut: json['clock_out'],
      status: json['status'],
      clockInPhoto: json['clock_in_photo'],
      clockOutPhoto: json['clock_out_photo'],
      clockInAddress: json['clock_in_address'],
      clockOutAddress: json['clock_out_address'],
      note: json['note'],
      isOutsideRadius: json['is_outside_radius'] as bool? ?? false,
      clockInLocationReason: json['clock_in_location_reason'] as String?,
      clockOutLocationReason: json['clock_out_location_reason'] as String?,
      clockInOfficeLocation: json['clock_in_office_location'] == null
          ? null
          : OfficeLocationModel.fromJson(
              Map<String, dynamic>.from(json['clock_in_office_location']),
            ),
      clockOutOfficeLocation: json['clock_out_office_location'] == null
          ? null
          : OfficeLocationModel.fromJson(
              Map<String, dynamic>.from(json['clock_out_office_location']),
            ),
    );
  }
}

class OfficeLocationModel {
  final String name;
  final double latitude;
  final double longitude;
  final int radius;

  OfficeLocationModel({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory OfficeLocationModel.fromJson(Map<String, dynamic> json) {
    return OfficeLocationModel(
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: json['radius'] as int,
    );
  }
}

class ClockInResultModel {
  final String message;
  final String clockIn;
  final String status;
  final String? note;
  final String? photoUrl;

  ClockInResultModel({
    required this.message,
    required this.clockIn,
    required this.status,
    this.note,
    this.photoUrl,
  });

  factory ClockInResultModel.fromJson(Map<String, dynamic> json) {
    return ClockInResultModel(
      message: json['message'] as String,
      clockIn: json['clock_in'] as String,
      status: json['status'] as String,
      note: json['note'] as String?,
      photoUrl: json['photo_url'] as String?,
    );
  }
}
