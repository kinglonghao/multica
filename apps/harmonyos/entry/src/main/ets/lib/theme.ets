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
 *
 * Note (C-2 / C-4): ArkTS forbids `as const` (and the dynamic bracket
 * access it implies at type-check sites). We use explicit object
 * literals with `Record<string, number>` and let components pick values
 * via a typed accessor function (`space()`, `radius()`) so the
 * property key is statically known at the call site.
 */

export type ColorScheme = 'light' | 'dark';

export type TextColorKey =
  | 'foreground'
  | 'mutedForeground'
  | 'destructive'
  | 'brand'
  | 'success'
  | 'warning'
  | 'brandForeground'
  | 'agentForeground';

export type SpaceKey =
  | '0' | '0.5' | '1' | '1.5' | '2' | '2.5' | '3' | '3.5' | '4'
  | '5' | '6' | '7' | '8' | '9' | '10' | '12' | '16' | '20';

export type RadiusKey = 'none' | 'sm' | 'DEFAULT' | 'md' | 'lg' | 'xl' | '2xl' | 'full';

export type FontSizeKey = 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl';

export type FontWeightKey = 'normal' | 'medium' | 'semibold' | 'bold';

export interface ThemeTokens {
  // Surface
  background: string;
  card: string;
  foreground: string;
  mutedForeground: string;
  border: string;

  // Brand
  brand: string;
  brandForeground: string;
  agent: string;
  agentForeground: string;

  // Status colors
  destructive: string;
  success: string;
  warning: string;

  // Status icons
  statusBacklog: string;
  statusTodo: string;
  statusInProgress: string;
  statusInReview: string;
  statusDone: string;
  statusCancelled: string;

  // Priority
  priorityUrgent: string;
  priorityHigh: string;
  priorityMedium: string;
  priorityLow: string;
  priorityNone: string;
}

interface ThemeMap {
  light: ThemeTokens;
  dark: ThemeTokens;
}

interface SpaceTokens {
  '0': number;
  '0.5': number;
  '1': number;
  '1.5': number;
  '2': number;
  '2.5': number;
  '3': number;
  '3.5': number;
  '4': number;
  '5': number;
  '6': number;
  '7': number;
  '8': number;
  '9': number;
  '10': number;
  '12': number;
  '16': number;
  '20': number;
}

interface RadiusTokens {
  none: number;
  sm: number;
  DEFAULT: number;
  md: number;
  lg: number;
  xl: number;
  '2xl': number;
  full: number;
}

interface FontSizeTokens {
  xs: number;
  sm: number;
  base: number;
  md: number;
  lg: number;
  xl: number;
  '2xl': number;
  '3xl': number;
}

interface FontWeightTokens {
  normal: number;
  medium: number;
  semibold: number;
  bold: number;
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

export const THEME: ThemeMap = {
  light,
  dark
};

/**
 * Static text-color lookup. Components call `textColor(scheme, key)`
 * instead of doing `THEME[scheme][key]` — the latter is dynamic
 * bracket access, which ArkTS forbids. The `switch` makes the
 * property selection static at the call site and survives strict
 * type checking.
 */
export const textColor: (scheme: ColorScheme, key: TextColorKey) => string =
  (scheme: ColorScheme, key: TextColorKey): string => {
    const t = themeTokens(scheme);
    switch (key) {
      case 'foreground': return t.foreground;
      case 'mutedForeground': return t.mutedForeground;
      case 'destructive': return t.destructive;
      case 'brand': return t.brand;
      case 'success': return t.success;
      case 'warning': return t.warning;
      case 'brandForeground': return t.brandForeground;
      case 'agentForeground': return t.agentForeground;
      default: return t.foreground;
    }
  };

/**
 * Spacing tokens. iOS uses Tailwind's 4-unit scale; ArkUI uses vp
 * (virtual pixels) with a 4-unit system that's close enough to call
 * 1:1. The 1.5/2.5 increments follow Tailwind's half-steps.
 */
export const SPACE: SpaceTokens = {
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
};

export const RADIUS: RadiusTokens = {
  none: 0,
  sm: 4,
  DEFAULT: 6,
  md: 8,
  lg: 12,
  xl: 16,
  '2xl': 20,
  full: 9999
};

export const FONT_SIZE: FontSizeTokens = {
  xs: 11,
  sm: 13,
  base: 14,
  md: 15,
  lg: 17,
  xl: 20,
  '2xl': 24,
  '3xl': 30
};

export const FONT_WEIGHT: FontWeightTokens = {
  normal: 400,
  medium: 500,
  semibold: 600,
  bold: 700
};

export function themeTokens(scheme: ColorScheme): ThemeTokens {
  switch (scheme) {
    case 'dark':
      return dark;
    case 'light':
    default:
      return light;
  }
}

export function space(key: SpaceKey): number {
  switch (key) {
    case '0': return 0;
    case '0.5': return 2;
    case '1': return 4;
    case '1.5': return 6;
    case '2': return 8;
    case '2.5': return 10;
    case '3': return 12;
    case '3.5': return 14;
    case '4': return 16;
    case '5': return 20;
    case '6': return 24;
    case '7': return 28;
    case '8': return 32;
    case '9': return 36;
    case '10': return 40;
    case '12': return 48;
    case '16': return 64;
    case '20': return 80;
    default: return 0;
  }
}

export function fontSize(key: FontSizeKey): number {
  switch (key) {
    case 'xs': return 11;
    case 'sm': return 13;
    case 'base': return 14;
    case 'md': return 15;
    case 'lg': return 17;
    case 'xl': return 20;
    case '2xl': return 24;
    case '3xl': return 30;
    default: return 14;
  }
}

export function fontWeight(key: FontWeightKey): number {
  switch (key) {
    case 'normal': return 400;
    case 'medium': return 500;
    case 'semibold': return 600;
    case 'bold': return 700;
    default: return 400;
  }
}
