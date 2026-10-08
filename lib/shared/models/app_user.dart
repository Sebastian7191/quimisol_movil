class AppUser {
  final String id;
  final String? name;
  final String email;
  final String? photo;
  final String? role;

  AppUser({
    required this.id,
    required this.email,
    this.name,
    this.photo,
    this.role,
  });

  factory AppUser.fromMap(String id, Map<String, dynamic> data) {
    return AppUser(
      id: id,
      email: data['email'] ?? '',
      name: data['name'],
      photo: data['photo'],
      role: data['role'],
    );
  }
}
