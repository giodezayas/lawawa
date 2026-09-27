export function moneyTone(value: number): string {
  if (value > 0) {
    return 'text-success';
  }
  if (value < 0) {
    return 'text-danger';
  }
  return 'text-ink';
}
