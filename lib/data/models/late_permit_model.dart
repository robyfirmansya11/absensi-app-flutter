class LatePermitDraft {
  final DateTime date;
  final String arrivalTime;
  final String reason;

  const LatePermitDraft({
    required this.date,
    required this.arrivalTime,
    required this.reason,
  });

  String? validate({DateTime? now}) {
    final today = now ?? DateTime.now();
    if (DateTime(
      date.year,
      date.month,
      date.day,
    ).isAfter(DateTime(today.year, today.month, today.day))) {
      return 'The date cannot be in the future.';
    }
    if (!RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(arrivalTime)) {
      return 'Select a valid arrival time.';
    }
    if (reason.trim().isEmpty) return 'Provide a reason for your late arrival.';
    if (reason.length > 5000) {
      return 'The reason must not exceed 5,000 characters.';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final error = validate();
    if (error != null) throw ArgumentError(error);
    String pad(int n) => n.toString().padLeft(2, '0');
    return {
      'tanggal': '${date.year}-${pad(date.month)}-${pad(date.day)}',
      'jam_masuk': arrivalTime,
      'alasan': reason.trim(),
    };
  }
}

class LatePermitModel {
  final int id;
  final String date;
  final String arrivalTime;
  final String reason;
  final String status;
  final int approvalLevel;
  final bool canCancel;
  final String? rejectedNote;
  final String? employeeName;
  final String? departmentName;
  final bool canApprove;

  const LatePermitModel({
    required this.id,
    required this.date,
    required this.arrivalTime,
    required this.reason,
    required this.status,
    required this.approvalLevel,
    required this.canCancel,
    this.rejectedNote,
    this.employeeName,
    this.departmentName,
    this.canApprove = false,
  });

  factory LatePermitModel.fromJson(Map<String, dynamic> json) =>
      LatePermitModel(
        id: (json['id'] as num).toInt(),
        date: json['tanggal'] as String,
        arrivalTime: json['jam_masuk'] as String,
        reason: json['alasan'] as String,
        status: json['status'] as String,
        approvalLevel: (json['approval_level'] as num).toInt(),
        canCancel: json['can_cancel'] == true,
        rejectedNote: json['rejected_note'] as String?,
        employeeName: json['employee_name'] as String?,
        departmentName: json['department_name'] as String?,
        canApprove: json['can_approve'] == true,
      );

  String get statusLabel => switch (status) {
    'Pending Approval' =>
      approvalLevel == 1
          ? 'Awaiting Supervisor Approval'
          : 'Awaiting HR Approval',
    'Approved' => 'Approved',
    'Rejected' => 'Rejected',
    'Cancelled' => 'Cancelled',
    'Submitted' => 'Submitted',
    _ => status,
  };
}
