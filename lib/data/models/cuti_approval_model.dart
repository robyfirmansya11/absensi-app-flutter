class CutiApprovalModel {
  final int id;
  final String employeeName;
  final String? department;
  final String jenisCuti;
  final String tanggalMulai;
  final String tanggalSelesai;
  final String formattedMulai;
  final String formattedSelesai;
  final int jumlahHari;
  final String alasan;
  final String status;
  final int approvalLevel;
  final String? createdAt;
  final bool canApprove;
  final bool canReject;
  String get stageLabel => switch (approvalLevel) {
    1 => 'Awaiting Manager Approval',
    2 => 'Awaiting Finance Manager Approval',
    3 => 'Awaiting HR Approval',
    _ => status,
  };

  CutiApprovalModel({
    required this.id,
    required this.employeeName,
    this.department,
    required this.jenisCuti,
    required this.tanggalMulai,
    required this.tanggalSelesai,
    required this.formattedMulai,
    required this.formattedSelesai,
    required this.jumlahHari,
    required this.alasan,
    required this.status,
    required this.approvalLevel,
    this.createdAt,
    this.canApprove = false,
    this.canReject = false,
  });

  factory CutiApprovalModel.fromJson(Map<String, dynamic> json) {
    return CutiApprovalModel(
      id: json['id'] as int,
      employeeName: json['employee_name'] as String? ?? '-',
      department: json['department'] as String?,
      jenisCuti: json['jenis_cuti'] as String,
      tanggalMulai: json['tanggal_mulai'] as String,
      tanggalSelesai: json['tanggal_selesai'] as String,
      formattedMulai: json['formatted_mulai'] as String? ?? '',
      formattedSelesai: json['formatted_selesai'] as String? ?? '',
      jumlahHari: json['jumlah_hari'] as int,
      alasan: json['alasan'] as String,
      status: json['status'] as String,
      approvalLevel: json['approval_level'] as int,
      createdAt: json['created_at'] as String?,
      canApprove: json['can_approve'] == true,
      canReject: json['can_reject'] == true,
    );
  }
}
