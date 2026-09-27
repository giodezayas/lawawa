export const colors = {
  primary: '#DC2626',
  primaryDark: '#B91C1C',
  primarySoft: '#EF4444',
  accent: '#FFD400',
  accentSoft: '#FFE566',
  cream: '#FFFFFF',
  creamDark: '#F3F4F6',
  surface: '#FFFFFF',
  ink: '#171717',
  muted: '#737373',
  line: '#E5E5E5',
  success: '#16A34A',
  danger: '#DC2626',
} as const;

export const spacing = {
  xs: 4,
  sm: 8,
  md: 16,
  lg: 24,
  xl: 32,
  xxl: 48,
} as const;

export const radii = {
  sm: 10,
  md: 16,
  lg: 24,
  pill: 999,
} as const;

export const typography = {
  fontFamily: 'Plus Jakarta Sans, system-ui, sans-serif',
  brand: 'La Wawa',
  product: 'Gestión',
} as const;

export type AppColors = typeof colors;
