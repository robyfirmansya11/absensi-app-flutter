class UserModel {
  final int id;
  final String name;
  final String email;
  final String? jabatan;
  final String? department;
  final String? foto;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.jabatan,
    this.department,
    this.foto,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      jabatan: json['jabatan'] as String?,
      department: json['department'] as String?,
      foto: json['foto'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'jabatan': jabatan,
      'department': department,
      'foto': foto,
    };
  }
}
