class UserModel {
  final int id;
  final String name;
  final String email;
  final String? jabatan;
  final String? department;
  final String? foto;
  final String? level;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.jabatan,
    this.department,
    this.foto,
    this.level,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      jabatan: json['jabatan'] as String?,
      department: json['department'] as String?,
      foto: json['foto'] as String?,
      level: json['level'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'level': level,
      'jabatan': jabatan,
      'department': department,
      'foto': foto,
    };
  }

  // ── ROLE HELPERS — samakan logika dengan User.php di Laravel ──

  bool get isSuperuser => level == 'Superuser';

  bool get isAdmin => level == 'Admin';

  bool get isSuperadmin => level == 'Superadmin';

  bool get isUser => level == 'User';

  /// HRD = Admin dengan jabatan tepat 'HRD' (sama seperti User::isHRD() di Laravel)
  bool get isHRD => level == 'Admin' && jabatan == 'HRD';

  /// Siapa saja yang berwenang approve (Superuser untuk level 1, HRD untuk level 2)
  bool get canApprove => isSuperuser || isHRD || isSuperadmin;
  bool get canReviewLeave =>
      isSuperuser || isAdmin || isSuperadmin || jabatan == 'Finance Manager';
}
