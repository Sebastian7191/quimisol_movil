
class UserRow {
  final String uid;
  final String name;
  final String email;
  final String photo;
  final String role;
  final String almacenId;

  const UserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.photo,
    required this.role,
    required this.almacenId,
  });

  factory UserRow.fromFirestore(String uid, Map<String, dynamic> data) {
    return UserRow(
      uid: uid,
      name: (data['name'] ?? 'Usuario').toString(),
      email: (data['email'] ?? '').toString(),
      photo: (data['photo'] ?? '').toString(),
      role: (data['role'] ?? 'cliente').toString().toLowerCase(),
      almacenId: (data['almacenId'] ?? '').toString(),
    );
  }
}
