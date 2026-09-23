class OvertimeDraft {
  final DateTime month;
  final DateTime date;
  final String workStart;
  final String workEnd;
  final String overtimeStart;
  final String overtimeEnd;
  final double? mealAllowance;
  final String description;

  const OvertimeDraft({
    required this.month,
    required this.date,
    required this.workStart,
    required this.workEnd,
    required this.overtimeStart,
    required this.overtimeEnd,
    this.mealAllowance,
    required this.description,
  });

  static int minutes(String time) {
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(time)) {
      throw const FormatException('Enter the time in HH:mm format.');
    }
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  double get hours => (minutes(overtimeEnd) - minutes(overtimeStart)) / 60;

  String? validate() {
    try {
      if (minutes(workEnd) <= minutes(workStart)) {
        return 'The work end time must be after the work start time.';
      }
      if (hours <= 0) {
        return 'The overtime end time must be after the overtime start time.';
      }
    } on FormatException catch (e) {
      return e.message;
    }
    if (description.trim().isEmpty) return 'Provide a work description.';
    if (description.length > 5000) {
      return 'The work description must not exceed 5,000 characters.';
    }
    if (mealAllowance != null &&
        (!mealAllowance!.isFinite ||
            mealAllowance! < 0 ||
            mealAllowance! > 9999999999.99)) {
      return 'The meal allowance must be zero or greater.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    String pad(int n) => n.toString().padLeft(2, '0');
    return {
      'bulan_lembur': '${month.year}-${pad(month.month)}',
      'tanggal_lembur': '${date.year}-${pad(date.month)}-${pad(date.day)}',
      'mulai_kerja': workStart,
      'selesai_kerja': workEnd,
      'mulai_lembur': overtimeStart,
      'selesai_lembur': overtimeEnd,
      'jumlah_jam_lembur': double.parse(hours.toStringAsFixed(2)),
      'uang_makan': mealAllowance,
      'uraian_pekerjaan': description.trim(),
    };
  }
}

class OvertimeModel {
  final int id;
  final String month;
  final String date;
  final String workStart;
  final String workEnd;
  final String overtimeStart;
  final String overtimeEnd;
  final double hours;
  final double? mealAllowance;
  final String description;
  final String status;
  final int approvalLevel;
  final bool canCancel;
  final String? rejectedNote;
  final String? employeeName;
  final String? departmentName;
  final bool canApprove;

  const OvertimeModel({
    required this.id,
    required this.month,
    required this.date,
    required this.workStart,
    required this.workEnd,
    required this.overtimeStart,
    required this.overtimeEnd,
    required this.hours,
    this.mealAllowance,
    required this.description,
    required this.status,
    this.approvalLevel = 0,
    this.canCancel = false,
    this.rejectedNote,
    this.employeeName,
    this.departmentName,
    this.canApprove = false,
  });

  factory OvertimeModel.fromJson(Map<String, dynamic> json) {
    String time(Object? value) {
      final raw = value?.toString() ?? '';
      final match = RegExp(r'(?:^|T|\s)(\d{2}:\d{2})').firstMatch(raw);
      return match?.group(1) ?? raw;
    }

    return OvertimeModel(
      id: int.parse('${json['id']}'),
      month: json['bulan_lembur']?.toString() ?? '',
      date: (json['tanggal_lembur']?.toString() ?? '').split('T').first,
      workStart: time(json['mulai_kerja']),
      workEnd: time(json['selesai_kerja']),
      overtimeStart: time(json['mulai_lembur']),
      overtimeEnd: time(json['selesai_lembur']),
      hours: double.parse('${json['jumlah_jam_lembur']}'),
      mealAllowance: double.tryParse('${json['uang_makan']}'),
      description: json['uraian_pekerjaan']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      approvalLevel: int.tryParse('${json['approval_level']}') ?? 0,
      canCancel: json['can_cancel'] == true,
      rejectedNote: json['rejected_note'] as String?,
      employeeName: json['employee_name'] as String?,
      departmentName: json['department_name'] as String?,
      canApprove: json['can_approve'] == true,
    );
  }

  String get statusLabel => switch (status.toLowerCase()) {
    'pending approval' =>
      approvalLevel == 1
          ? 'Awaiting Supervisor Approval'
          : 'Awaiting HR Approval',
    'submitted' => 'Submitted',
    'pending' => 'Pending Approval',
    'approved' => 'Approved',
    'rejected' => 'Rejected',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}
