class UserProfile {
  const UserProfile({
    required this.email,
    required this.nik,
    required this.role,
    required this.code,
    required this.loa,
    required this.name,
  });

  final String email;
  final String nik;
  final String role;
  final String code;
  final String loa;
  final String name;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      email: json['email'] as String,
      nik: json['nik'] as String,
      role: json['role'] as String,
      code: json['code'] as String,
      loa: json['loa'] as String,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'nik': nik,
      'role': role,
      'code': code,
      'loa': loa,
      'name': name,
    };
  }
}
