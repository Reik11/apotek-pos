class UserModel {
  final String id;
  final String name;
  final String email;
  final String role;
  final String? outletId;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.outletId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      outletId: json['outletId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'outletId': outletId,
    };
  }
}