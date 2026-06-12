import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { THEME, ColorScheme, SPACE, RADIUS, textColor, TextColorKey } from '../lib/theme';
import { themeController, ThemePreference } from '../lib/theme-controller';
import { localeController, LocalePreference, t } from '../lib/locale';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { MulticaLogo } from '../components/brand/MulticaLogo';

/**
 * Settings — Appearance, Language, Account info, sign-out.
 *
 * Mirrors the inline picker pattern from
 * `apps/mobile/app/(app)/[workspace]/more/settings.tsx` but as
 * a dedicated HarmonyOS page. Two inline radio-like pickers
 * (one for appearance, one for language) plus a destructive
 * sign-out button. All state writes go through the controllers
 * (themeController, localeController) which persist to the
 * shared `Preferences` snapshot and notify subscribers.
 */
@ComponentV2
export struct SettingsPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local signingOut: boolean = false;
  @Local signOutError: string = '';
  private themeUnsub?: () => void;
  private localeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.localeUnsub = localeController.subscribe(() => { this.version++; });
  }

  aboutToDisappear(): void {
    this.themeUnsub?.();
    this.localeUnsub?.();
  }

  private async pickTheme(p: ThemePreference): Promise<void> {
    await themeController.setPreference(p);
  }

  private async pickLocale(p: LocalePreference): Promise<void> {
    await localeController.setPreference(p);
  }

  private async signOut(): Promise<void> {
    this.signingOut = true;
    this.signOutError = '';
    try {
      // Clear local state and bounce to login. The auth store
      // does the heavy lifting; we just route.
      await authStore.logout();
      appNavigation.clearStack();
      appNavigation.pushName('LoginPage');
    } catch (err) {
      this.signOutError = err instanceof Error ? err.message : t('more_sign_out_failed');
    } finally {
      this.signingOut = false;
    }
  }

  build() {
    Column() {
      Header({
        title: t('settings_title'),
        scheme: this.scheme,
        left: this.BackButton()
      })

      Scroll() {
        Column() {
          // ---- Brand strip + workspace banner ----
          Row() {
            MulticaLogo({ scheme: this.scheme, size: 'md' })
            Blank()
            MulticaText({
              value: 'v0.1.0',
              scheme: this.scheme,
              size: 'xs',
              color: 'mutedForeground'
            })
          }
          .width('100%')
          .padding(SPACE['4'])
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))
          .alignItems(VerticalAlign.Center)

          // ---- Appearance ----
          this.SectionTitle(t('settings_appearance'))

          Column() {
            this.RadioRow('theme', 'light', t('settings_appearance_light'), '☀')
            this.Divider()
            this.RadioRow('theme', 'dark', t('settings_appearance_dark'), '🌙')
            this.Divider()
            this.RadioRow('theme', 'system', t('settings_appearance_system'), '◐')
          }
          .width('100%')
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))

          // ---- Language ----
          this.SectionTitle(t('settings_language'))

          Column() {
            this.RadioRow('language', 'en', t('settings_language_en'), 'EN')
            this.Divider()
            this.RadioRow('language', 'zh', t('settings_language_zh'), '中')
          }
          .width('100%')
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))

          // ---- Account ----
          this.SectionTitle(t('settings_account'))

          Column() {
            this.AccountRow()
          }
          .width('100%')
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))

          if (this.signOutError) {
            MulticaText({
              value: this.signOutError,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .width('100%')
              .padding(SPACE['3'])
          }

          // ---- Sign out ----
          MulticaButton({
            label: this.signingOut ? '…' : t('common_sign_out'),
            scheme: this.scheme,
            variant: 'destructive',
            fullWidth: true,
            disabled: this.signingOut,
            onTap: () => { void this.signOut(); }
          })
            .margin({ top: SPACE['6'] })
        }
        .padding(SPACE['4'])
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder SectionTitle(title: string) {
    MulticaText({
      value: title,
      scheme: this.scheme,
      size: 'xs',
      weight: 'semibold',
      color: 'mutedForeground'
    })
      .width('100%')
      .padding({ left: SPACE['1'], top: SPACE['6'], bottom: SPACE['2'] })
  }

  @Builder Divider() {
    Row()
      .width('100%')
      .height(1)
      .backgroundColor(String(THEME[this.scheme].border))
  }

  /**
   * Generic radio-style row. The `group` is the union of values
   * within a single picker; the `value` is the candidate option
   * the row represents. Tapping sets the matching controller.
   */
  @Builder RadioRow(group: 'theme' | 'language', value: string, label: string, glyph: string) {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        MulticaText({
          value: glyph,
          scheme: this.scheme,
          size: 'base',
          color: 'foreground'
        })
      }
      .width(28)
      .height(28)
      .borderRadius(RADIUS.full)
      .backgroundColor(String(THEME[this.scheme].background))
      .margin({ right: SPACE['3'] })

      MulticaText({
        value: label,
        scheme: this.scheme,
        size: 'base',
        color: 'foreground'
      })

      Blank()

      Stack({ alignContent: Alignment.Center }) {
        Stack()
          .width(20)
          .height(20)
          .borderRadius(10)
          .border({
            width: 2,
            color: this.isSelected(group, value) ? String(THEME[this.scheme].brand) : String(THEME[this.scheme].border)
          })
          .backgroundColor(this.isSelected(group, value) ? String(THEME[this.scheme].brand) : 'transparent')
        if (this.isSelected(group, value)) {
          Stack()
            .width(8)
            .height(8)
            .borderRadius(4)
            .backgroundColor(String(THEME[this.scheme].brandForeground))
        }
      }
      .width(20)
      .height(20)
    }
    .width('100%')
    .padding(SPACE['3'])
    .onClick(() => {
      if (group === 'theme') {
        void this.pickTheme(value as ThemePreference);
      } else {
        void this.pickLocale(value as LocalePreference);
      }
    })
  }

  @Builder AccountRow() {
    const state = authStore.getState();
    const user = state.user;
    const ws = workspaceStore.getState().current;
    Column() {
      MulticaText({
        value: user?.display_name ?? user?.email ?? '—',
        scheme: this.scheme,
        size: 'base',
        weight: 'medium',
        color: 'foreground'
      })
      MulticaText({
        value: user?.email ?? '',
        scheme: this.scheme,
        size: 'sm',
        color: 'mutedForeground'
      })
        .margin({ top: SPACE['0.5'] })
      if (ws) {
        MulticaText({
          value: `${t('more_workspace_label')}: ${ws.name}`,
          scheme: this.scheme,
          size: 'sm',
          color: 'mutedForeground'
        })
          .margin({ top: SPACE['0.5'] })
      }
    }
    .padding(SPACE['3'])
    .alignItems(HorizontalAlign.Start)
  }

  private isSelected(group: 'theme' | 'language', value: string): boolean {
    if (group === 'theme') {
      return themeController.pref === value;
    }
    return localeController.pref === value;
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: t('common_back'),
      onTap: () => { appNavigation.pop(); }
    })
  }
}
