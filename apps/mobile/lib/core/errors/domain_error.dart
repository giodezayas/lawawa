class DomainError implements Exception {
  const DomainError(this.message, this.code);

  final String message;
  final String code;

  @override
  String toString() => message;
}

abstract final class AuthErrorCodes {
  static const invalidCredentials = 'AUTH_INVALID_CREDENTIALS';
  static const inactiveUser = 'AUTH_INACTIVE_USER';
  static const unauthenticated = 'AUTH_UNAUTHENTICATED';
  static const invalidInput = 'AUTH_INVALID_INPUT';
  static const profileMissing = 'AUTH_PROFILE_MISSING';
}
