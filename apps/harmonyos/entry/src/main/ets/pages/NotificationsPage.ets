import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle } from '../queries/cache';
import { NotificationPreferences, NotificationPreference } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Skeleton } from '../components/ui/Skeleton';
import { MulticaButton } from '../components/ui/Button';

const PREFS_QUERY_KEY: readonly string[] = ['notification-prefs', 'self'];
const PREFS_STALE_MS = 60_000;

@ComponentV2
export struct NotificationsPage {
  @Local scheme: ColorScheme = 'light';
  @Local saving: boolean = false;
  @Local errorMessage: string = '';
  @Local success: boolean = false;
  @Local version: number = 0;
  /** Immutable snapshot of the prefs list. Each toggle creates a new
   *  array via `setPref(prefs, index, next)` rather than mutating
   *  in place — fixes H-3 (the v0.2 code did `pref.enabled = isOn`
   *  directly, which both breaks the immutability rule AND doesn't
   *  fire the page's onUpdate because the cache object identity is
   *  preserved). */
  @Local prefs: NotificationPreference[] = [];
  private query: QueryHandle<NotificationPreferences> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useQuery<NotificationPreferences>(
      PREFS_QUERY_KEY,
      ({ signal }) => api.getNotificationPreferences({ signal }),
      {
        staleTimeMs: PREFS_STALE_MS,
        onUpdate: () => {
          this.version++;
          // Mirror the cache into local @Local state so the toggle
          // mutations below can build a new array off of it.
          const s = this.query?.getState();
          if (s?.data) this.prefs = [...s.data.preferences];
        }
      }
    );
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  /** Toggle handler — produces a NEW prefs array (immutable), and
   *  also patches the cache so subsequent reads (e.g. on save)
   *  see the toggle applied. This is the React-style "lift state up"
   *  pattern adapted to V2: cache holds the truth, local @Local
   *  holds the snapshot that the page renders. */
  private togglePref(index: number, next: boolean): void {
    const before = this.prefs;
    const after = before.map((p, i) => i === index ? { ...p, enabled: next } : p);
    this.prefs = after;
    if (this.query?.getState().data) {
      this.query.getState().data!.preferences = after;
    }
  }

  private async save(): Promise<void> {
    const data = this.query?.getState().data;
    if (!data) return;
    this.saving = true;
    this.errorMessage = '';
    this.success = false;
    try {
      // Send the locally-edited prefs back, NOT a fresh GET.
      const updated: NotificationPreferences = { ...data, preferences: this.prefs };
      const saved = await api.updateNotificationPreferences(updated);
      this.success = true;
      if (this.query?.getState().data) {
        this.query.getState().data!.preferences = saved.preferences;
      }
      this.prefs = [...saved.preferences];
    } catch (err) {
      // H-7: surface save errors to the user. The earlier v0.2 code
      // silently logged `[notifications] save failed` and let the user
      // think the change had been saved.
      this.errorMessage = err instanceof Error ? err.message : 'Failed to save notification preferences';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Notifications',
        scheme: this.scheme,
        left: this.BackButton(),
        right: this.SaveButton()
      })

      if (!this.query) {
        return;
      }
      const state = this.query.getState();
      if (state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Skeleton({ scheme: this.scheme, width: '90%', height: 56, radius: 8 })
              .margin({ top: SPACE['3'] })
          })
        }
        .padding(SPACE['4'])
      } else {
        Column() {
          // Render from this.prefs (immutable snapshot), not the cache
          // array directly. The cache's array reference may stay the
          // same across toggles — using it as the render source would
          // prevent the toggle UI from refreshing.
          ForEach(this.prefs, (pref: NotificationPreference, index?: number) => {
            Row() {
              Column() {
                MulticaText({
                  value: pref.category,
                  scheme: this.scheme,
                  size: 'base',
                  weight: 'medium',
                  color: 'foreground'
                })
                MulticaText({
                  value: pref.channel,
                  scheme: this.scheme,
                  size: 'xs',
                  color: 'mutedForeground'
                })
                  .margin({ top: SPACE['0.5'] })
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)

              Toggle({ type: ToggleType.Switch, isOn: pref.enabled })
                .onChange((isOn: boolean) => {
                  this.togglePref(index ?? 0, isOn);
                })
            }
            .width('100%')
            .padding(SPACE['4'])
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .margin({ top: SPACE['2'] })
          })

          if (this.errorMessage) {
            MulticaText({
              value: this.errorMessage,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .margin({ top: SPACE['2'] })
              .width('100%')
          }

          if (this.success) {
            MulticaText({
              value: 'Saved',
              scheme: this.scheme,
              size: 'sm',
              color: 'success'
            })
              .margin({ top: SPACE['2'] })
          }
        }
        .padding(SPACE['4'])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }

  @Builder SaveButton() {
    MulticaButton({
      label: this.saving ? 'Saving…' : 'Save',
      scheme: this.scheme,
      variant: 'primary',
      size: 'sm',
      disabled: this.saving,
      onTap: () => { void this.save(); }
    })
  }
}
