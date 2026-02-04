// lib/models/instructor_profile_model.dart
class InstructorProfile {
  final int id;
  final String? firstname;
  final String? lastname;
  final String email;
  final String? userId;
  final String createdAt;
  final String updatedAt;
  final bool isDeleted;
  final String? deletedAt;

  InstructorProfile({
    required this.id,
    this.firstname,
    this.lastname,
    required this.email,
    this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    this.deletedAt,
  });

  factory InstructorProfile.fromJson(Map<String, dynamic> json) {
    return InstructorProfile(
      id: json['id'] ?? 0,
      firstname: json['firstname'],
      lastname: json['lastname'],
      email: json['email'] ?? '',
      userId: json['userId'],
      createdAt: json['createdAt'] ?? '',
      updatedAt: json['updatedAt'] ?? '',
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'firstname': firstname,
      'lastname': lastname,
      'email': email,
      'userId': userId,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'isDeleted': isDeleted,
      'deletedAt': deletedAt,
    };
  }

  String get fullName {
    if (firstname != null && lastname != null) {
      return '$firstname $lastname';
    } else if (firstname != null) {
      return firstname!;
    } else if (lastname != null) {
      return lastname!;
    }
    return 'Instructor $id';
  }
}

