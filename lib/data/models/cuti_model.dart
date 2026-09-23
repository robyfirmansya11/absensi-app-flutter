class CutiModel {
  final int id;
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
  final String? manager;
  final String? hrd;
  final String? rejectedNote;
  final String? cancelledAt;

  CutiModel({
    required this.id,
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
    this.manager,
    this.hrd,
    this.rejectedNote,
    this.cancelledAt,
  });

  factory CutiModel.fromJson(Map<String, dynamic> json) {
    return CutiModel(
      id: json['id'] as int,
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
      manager: json['manager'] as String?,
      hrd: json['hrd'] as String?,
      rejectedNote: json['rejected_note'] as String?,
      cancelledAt: json['cancelled_at'] as String?,
    );
  }
}

class KuotaCutiModel {
  final int tahun;
  final int kuotaTahunan;
  final int cutiTerpakai;
  final int sisaCuti;

  KuotaCutiModel({
    required this.tahun,
    required this.kuotaTahunan,
    required this.cutiTerpakai,
    required this.sisaCuti,
  });

  factory KuotaCutiModel.fromJson(Map<String, dynamic> json) {
    return KuotaCutiModel(
      tahun: json['tahun'] as int,
      kuotaTahunan: json['kuota_tahunan'] as int,
      cutiTerpakai: json['cuti_terpakai'] as int,
      sisaCuti: json['sisa_cuti'] as int,
    );
  }
}
