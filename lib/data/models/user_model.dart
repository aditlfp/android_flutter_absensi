class UserModel {
  final String uid;
  final String name;
  final String email;
  final String department;
  final String position;
  final String faceEmbedding;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.department,
    required this.position,
    this.faceEmbedding = '',
  });
}
