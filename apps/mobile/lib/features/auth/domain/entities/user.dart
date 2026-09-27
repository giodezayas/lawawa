import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';

enum UserRole { admin, manager, trabajador }

@freezed
abstract class User with _$User {
  const User._();

  const factory User({
    required String id,
    required String email,
    required String fullName,
    required UserRole role,
    required bool isActive,
    required DateTime createdAt,
  }) = _User;

  String get displayName {
    final trimmed = fullName.trim();
    return trimmed.isEmpty ? email : trimmed;
  }

  bool get canManageStaff => role == UserRole.admin || role == UserRole.manager;

  String get roleLabel => switch (role) {
    UserRole.admin => 'Admin',
    UserRole.manager => 'Manager',
    UserRole.trabajador => 'Trabajador',
  };
}
