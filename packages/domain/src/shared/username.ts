export function isValidUsername(value: string): boolean {
  return /^[a-z][a-z0-9._-]{2,31}$/.test(value);
}
