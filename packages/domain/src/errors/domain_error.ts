export class DomainError extends Error {
  constructor(
    message: string,
    readonly code: string,
  ) {
    super(message);
    this.name = 'DomainError';
  }
}

export const AuthErrorCodes = {
  invalidCredentials: 'AUTH_INVALID_CREDENTIALS',
  inactiveUser: 'AUTH_INACTIVE_USER',
  unauthenticated: 'AUTH_UNAUTHENTICATED',
  invalidInput: 'AUTH_INVALID_INPUT',
  profileMissing: 'AUTH_PROFILE_MISSING',
  forbidden: 'AUTH_FORBIDDEN',
} as const;

export const InventoryErrorCodes = {
  invalidInput: 'INV_INVALID_INPUT',
  duplicate: 'INV_DUPLICATE',
  notFound: 'INV_NOT_FOUND',
  closed: 'INV_CLOSED',
} as const;
