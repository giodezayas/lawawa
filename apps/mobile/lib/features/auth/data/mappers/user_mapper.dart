import '../../domain/entities/user.dart';

abstract final class UserMapper {
  static User fromProfile(Map<String, dynamic> row) {
    return User(
      id: row['id'] as String,
      email: row['email'] as String,
      fullName: (row['full_name'] as String?) ?? '',
      role: _toRole(row['role'] as String?),
      isActive: (row['is_active'] as bool?) ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  static UserRole _toRole(String? value) {
    if (value == 'owner') {
      return UserRole.admin;
    }
    if (value == 'staff') {
      return UserRole.trabajador;
    }
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => UserRole.trabajador,
    );
  }
}
