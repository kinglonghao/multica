/**
 * Theme tokens for the HarmonyOS client. Mirrors apps/mobile/lib/theme.ts.
 *
 * CSS variables on iOS / web are sourced from `global.css`; here ArkUI
 * doesn't have a runtime CSS-variable layer, so we use plain TS objects
 * keyed by the current color scheme. Components pull from THEME[scheme]
 * at render time and we wrap the entire app in a theme controller that
 * updates @State to trigger re-render on mode change.
 *
 * When changing a color, change BOTH light and dark entries — there's no
 * "tokens.css" diff to catch a missed variant.
 */

export type ColorScheme = 'light' | 'dark';

export interface ThemeTokens {
  // Surface
  background: ResourceColor;
  card: ResourceColor;
  foreground: ResourceColor;
  mutedForeground: ResourceColor;
  border: ResourceColor;

  // Brand
  brand: ResourceColor;
  brandForeground: ResourceColor;
  agent: ResourceColor;
  agentForeground: ResourceColor;

  // Status colors
  destructive: ResourceColor;
  success: ResourceColor;
  warning: ResourceColor;

  // Status icons
  statusBacklog: ResourceColor;
  statusTodo: ResourceColor;
  statusInProgress: ResourceColor;
  statusInReview: ResourceColor;
  statusDone: ResourceColor;
  statusCancelled: ResourceColor;

  // Priority
  priorityUrgent: ResourceColor;
  priorityHigh: ResourceColor;
  priorityMedium: ResourceColor;
  priorityLow: ResourceColor;
  priorityNone: ResourceColor;
}

const light: ThemeTokens = {
  background: '#FFFFFF',
  card: '#F7F7F8',
  foreground: '#0A0A0A',
  mutedForeground: '#71717A',
  border: '#E4E4E7',

  brand: '#5046E4',
  brandForeground: '#FFFFFF',
  agent: '#9333EA',
  agentForeground: '#FFFFFF',

  destructive: '#DC2626',
  success: '#16A34A',
  warning: '#D97706',

  statusBacklog: '#A1A1AA',
  statusTodo: '#71717A',
  statusInProgress: '#F59E0B',
  statusInReview: '#3B82F6',
  statusDone: '#16A34A',
  statusCancelled: '#A1A1AA',

  priorityUrgent: '#DC2626',
  priorityHigh: '#EA580C',
  priorityMedium: '#CA8A04',
  priorityLow: '#2563EB',
  priorityNone: '#A1A1AA'
};

const dark: ThemeTokens = {
  background: '#0A0A0A',
  card: '#18181B',
  foreground: '#FAFAFA',
  mutedForeground: '#A1A1AA',
  border: '#27272A',

  brand: '#6366F1',
  brandForeground: '#FFFFFF',
  agent: '#A855F7',
  agentForeground: '#FFFFFF',

  destructive: '#EF4444',
  success: '#22C55E',
  warning: '#F59E0B',

  statusBacklog: '#52525B',
  statusTodo: '#A1A1AA',
  statusInProgress: '#FBBF24',
  statusInReview: '#60A5FA',
  statusDone: '#4ADE80',
  statusCancelled: '#52525B',

  priorityUrgent: '#EF4444',
  priorityHigh: '#FB923C',
  priorityMedium: '#EAB308',
  priorityLow: '#3B82F6',
  priorityNone: '#52525B'
};

export const THEME: Record<ColorScheme, ThemeTokens> = {
  light,
  dark
};

/**
 * Spacing tokens. iOS uses Tailwind's 4-unit scale; ArkUI uses vp
 * (virtual pixels) with a 4-unit system that's close enough to call
 * 1:1. The 1.5/2.5 increments follow Tailwind's half-steps.
 */
export const SPACE = {
  '0': 0,
  '0.5': 2,
  '1': 4,
  '1.5': 6,
  '2': 8,
  '2.5': 10,
  '3': 12,
  '3.5': 14,
  '4': 16,
  '5': 20,
  '6': 24,
  '7': 28,
  '8': 32,
  '9': 36,
  '10': 40,
  '12': 48,
  '16': 64,
  '20': 80
} as const;

export const RADIUS = {
  none: 0,
  sm: 4,
  DEFAULT: 6,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 20,
  full: 9999
} as const;

export const FONT_SIZE = {
  xs: 11,
  sm: 13,
  base: 14,
  md: 15,
  lg: 17,
  xl: 20,
  '2xl': 24,
  '3xl': 30
} as const;

export const FONT_WEIGHT = {
  normal: 400,
  medium: 500,
  semibold: 600,
  bold: 700
} as const;
