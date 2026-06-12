/**
 * ThemeController — owns the user-facing appearance preference
 * ('light' | 'dark' | 'system') and the resolved `ColorScheme`
 * ('light' | 'dark'). Mirrors apps/mobile/lib/use-color-scheme.ts.
 *
 * Why a singleton and not a hook? ArkTS V2 components re-render on
 * `@Local` field writes; the pages that care about theme already
 * hold their own `@Local scheme: ColorScheme` for re-render
 * purposes. The controller's job is the *shared* state — what the
 * user picked, what the system is reporting, and notifying
 * subscribers when either changes so each page can re-pull.
 *
 * Wire-up:
 *
 *   // In EntryAbility.onWindowStageCreate, after PreferencesBootstrap.init:
 *   await ThemeController.init(this.context);
 *   ThemeController.attachWindowStage(windowStage);
 *
 *   // In a page's aboutToAppear:
 *   this.scheme = themeController.scheme;
 *   this.unsub = themeController.subscribe(() => { this.scheme = themeController.scheme; });
 *
 *   // In aboutToDisappear:
 *   this.unsub?.();
 *
 *   // To switch:
 *   await themeController.setPreference('dark');
 *
 * Source of truth for the user's pick is `Preferences.themePref`
 * (string key 'theme_pref'). Source of truth for the OS scheme is
 * the system appearance change event fired by the framework on
 * the main window.
 */
import { ColorScheme } from './theme';
import { Preferences } from '../data/preferences';
import configurationConstant from '@ohos.app.ability.configurationConstant';
import window from '@ohos.window';
import common from '@ohos.app.ability.common';

export type ThemePreference = 'light' | 'dark' | 'system';

const DEFAULT_PREF: ThemePreference = 'system';

/**
 * Map a HarmonyOS configuration color mode to our ColorScheme.
 * HarmonyOS reports `configurationConstant.ColorMode.COLOR_MODE_DARK`
 * (value 0x10 on API 12) when dark mode is on. Anything else is light.
 */
function mapOsColorMode(os: number | undefined): ColorScheme {
  if (os === configurationConstant.ColorMode.COLOR_MODE_DARK) {
    return 'dark';
  }
  return 'light';
}

class ThemeControllerImpl {
  private preference: ThemePreference = DEFAULT_PREF;
  private resolved: ColorScheme = 'light';
  private readonly listeners = new Set<(scheme: ColorScheme) => void>();
  private osUnsub: (() => void) | null = null;
  private initialized = false;

  /**
   * Read the persisted preference, seed the resolved scheme, and
   * (best-effort) read the OS color mode. Idempotent.
   */
  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;

    // 1. Read the saved preference. PreferencesBootstrap is awaited
    //    BEFORE ThemeController.init in EntryAbility, so the snapshot
    //    is already in memory.
    const saved = Preferences.get('themePref');
    this.preference = (saved === 'light' || saved === 'dark' || saved === 'system')
      ? saved
      : DEFAULT_PREF;

    // 2. Compute the initial resolved scheme. We read the OS
    //    configuration off the ability's resourceManager — it's
    //    the same value the OS would broadcast via the appearance
    //    change event.
    const initialOs = this.readOsColorMode(context);
    this.resolved = this.computeResolved(this.preference, initialOs);
  }

  /**
   * Attach a WindowStage so we can listen for OS appearance
   * changes (system dark-mode toggles). Idempotent.
   */
  attachWindowStage(windowStage: window.WindowStage): void {
    if (this.osUnsub) {
      try { this.osUnsub(); } catch { /* ignore */ }
      this.osUnsub = null;
    }
    try {
      const win = windowStage.getMainWindowSync();
      // The system fires 'systemAppearanceChange' whenever the OS
      // color mode changes. The callback receives 'light' or 'dark'.
      win.on('systemAppearanceChange', (appearance: 'light' | 'dark') => {
        const newScheme: ColorScheme = appearance === 'dark' ? 'dark' : 'light';
        if (this.preference === 'system' && newScheme !== this.resolved) {
          this.resolved = newScheme;
          this.emit();
        }
      });
      this.osUnsub = () => {
        try { win.off('systemAppearanceChange'); } catch { /* ignore */ }
      };
    } catch (err) {
      // Older SDKs may not have 'systemAppearanceChange'. In that
      // case the user has to toggle the in-app preference to refresh.
      console.warn('[theme-controller] attachWindowStage failed', err);
    }
  }

  /**
   * The currently resolved scheme — what every page should bind to.
   */
  get scheme(): ColorScheme {
    return this.resolved;
  }

  /**
   * The user's explicit pick. 'system' means follow the OS.
   */
  get pref(): ThemePreference {
    return this.preference;
  }

  /**
   * Subscribe to scheme changes. Returns an unsubscribe function.
   * The subscriber is called with the new resolved scheme.
   */
  subscribe(listener: (scheme: ColorScheme) => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }

  /**
   * Switch the user's preference. Persists to disk and re-resolves
   * the scheme. Safe to call from a button onClick.
   */
  async setPreference(p: ThemePreference): Promise<void> {
    if (p !== 'light' && p !== 'dark' && p !== 'system') return;
    if (p === this.preference) return;
    this.preference = p;
    // Re-resolve. For 'light'/'dark' the resolved == preference; for
    // 'system' it tracks the OS.
    this.resolved = this.computeResolved(p, this.readOsColorMode(null));
    await Preferences.setThemePref(p);
    this.emit();
  }

  /**
   * Recompute the resolved scheme from the preference + the latest
   * OS hint. For 'light'/'dark' the resolved == preference; for
   * 'system' it tracks the OS.
   */
  private computeResolved(pref: ThemePreference, osScheme: ColorScheme): ColorScheme {
    if (pref === 'light') return 'light';
    if (pref === 'dark') return 'dark';
    return osScheme;
  }

  /**
   * Best-effort read of the OS color mode. Returns 'light' on any
   * failure — failing closed (light) is the safer default; users on
   * dark-mode systems will see a brief flash of light until the
   * appearance listener wakes up, but that's a one-frame cost.
   *
   * The system param API exposes the active color mode under the
   * 'ohos.colorMode' key. We read it via the application context
   * (passed in) or, on the read-only post-init path, via the
   * resource manager on whatever context is available.
   */
  private readOsColorMode(ctx: common.UIAbilityContext | null): ColorScheme {
    try {
      const fallback = ctx ?? globalThis.abilityContext as common.UIAbilityContext | null;
      if (fallback) {
        // resourceManager.getConfigurationSync() returns a Configuration
        // whose colorMode field is the ColorMode enum value.
        const cfg = fallback.resourceManager.getConfigurationSync();
        if (cfg && typeof cfg.colorMode === 'number') {
          return mapOsColorMode(cfg.colorMode);
        }
      }
    } catch { /* fall through */ }
    return 'light';
  }

  private emit(): void {
    for (const l of this.listeners) {
      try { l(this.resolved); } catch (err) {
        console.warn('[theme-controller] subscriber threw', err);
      }
    }
  }
}

export const themeController: ThemeControllerImpl = new ThemeControllerImpl();
