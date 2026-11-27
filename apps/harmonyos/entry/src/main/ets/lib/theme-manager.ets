/**
 * Theme manager for HarmonyOS application.
 * Provides persisted preference-aware theme detection.
 */

import { Preferences } from '../data/preferences';
import { ColorScheme } from './theme';

export type ThemePreference = 'light' | 'dark' | 'system';

export function onThemePreferenceChanged(listener: () => void): () => void {
  return Preferences.subscribe(() => {
    listener();
  });
}

export function getThemePreference(): ThemePreference {
  const pref = Preferences.getThemePref();
  return pref === 'light' || pref === 'dark' || pref === 'system' ? pref : 'system';
}

/**
 * Get the current app color scheme.
 *
 * HarmonyOS system-theme API wiring is still pending, so `system`
 * currently falls back to light mode. Explicit user choices must still
 * win so Settings -> Appearance behaves the same as iOS.
 */
export function getSystemColorScheme(): ColorScheme {
  return 'light';
}

export function detectSystemColorScheme(): ColorScheme {
  const pref = getThemePreference();
  if (pref === 'light' || pref === 'dark') return pref;
  return getSystemColorScheme();
}