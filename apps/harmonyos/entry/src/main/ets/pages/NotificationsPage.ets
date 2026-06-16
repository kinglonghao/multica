import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { NotificationPreferences, NotificationPreference } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
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
  // H-1 fix: @Local mirrors. See InboxPage.ets.
  @Local _isLoading: boolean = true;
  @Local _data: NotificationPreferences | undefined = undefined;
  @Local _error: Error | null = null;
  /** Immutable snapshot of the prefs list. Each toggle creates a new
   *  array via `setPref(prefs, index, next)` rather than mutating
   *  in place — fixes H-3 (the v0.2 code did `pref.enabled = isOn`
   *  directly, which both breaks the immutability rule AND doesn't
   *  fire the page's onUpdate because the cache object identity is
   *  preserved). */
  @Local prefs: NotificationPreference[] = [];
  private query: QueryHandle<NotificationPreferences> | null = null;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useQuery<NotificationPreferences>(
      PREFS_QUERY_KEY,
      (ctx: FetchContext) => api.getNotificationPreferences({ cancelToken: ctx.cancelToken }),
      {
        staleTimeMs: PREFS_STALE_MS,
        onUpdate: () => {
          this.version++;
          this.syncFromCache();
        }
      }
    );
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.globalUnsub?.();
  }

  private syncFromCache(): void {
    if (!this.query) return;
    const s = this.query.getState();
    this._isLoading = s.isLoading;
    this._data = s.data as NotificationPreferences | undefined;
    this._error = s.error;
    if (s.data) this.prefs = [...s.data.preferences];
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  /** Toggle handler — produces a NEW prefs array (immutable), and
   *  also patches the cache so subsequent reads (e.g. on save)
   *  see the toggle applied. This is the React-style "lift state up"
   *  pattern adapted to V2: cache holds the truth, local @Local
   *  holds the snapshot that the page renders. */
  private togglePref(index: number, next: boolean): void {
    const before = this.prefs;
    const after = before.map((p, i): NotificationPreference => {
      if (i !== index) return p;
      return { channel: p.channel, category: p.category, enabled: next };
    });
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
      const updated: NotificationPreferences = { workspace_id: data.workspace_id, preferences: this.prefs };
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

  private queryState() {
    return this.query ? this.query.getState() : null;
  }

  build() {
    Column() {
      if (this._isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 48, radius: RADIUS.lg })
              .margin({ top: space('2') })
          })
        }
        .layoutWeight(1)
        .padding({ left: space('3'), right: space('3'), top: space('3') })
        .width('100%')
      } else if (this._error) {
        MulticaText({
          value: `Failed to load notification preferences: ${this._error.message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        List({ space: 0 }) {
          ForEach(this.prefs, (pref: NotificationPreference, index?: number) => {
            ListItem() {
              Row() {
                Column() {
                  MulticaText({
                    value: pref.category,
                    scheme: this.scheme,
                    textSize: 'sm',
                    weight: 'medium',
                    color: 'foreground'
                  })
                  MulticaText({
                    value: pref.channel,
                    scheme: this.scheme,
                    textSize: 'xs',
                    color: 'mutedForeground'
                  })
                    .margin({ top: 2 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: pref.enabled })
                  .onChange((isOn: boolean) => {
                    this.togglePref(index ?? 0, isOn);
                  })
              }
              .width('100%')
              .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
              .onClick(() => {
                this.togglePref(index ?? 0, !pref.enabled);
              })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: space('3'), right: space('3'), top: space('3') })
        .divider(null)
        .backgroundColor(String(themeTokens(this.scheme).background))
      }

      if (this.errorMessage) {
        MulticaText({
          value: this.errorMessage,
          scheme: this.scheme,
          textSize: 'xs',
          color: 'destructive'
        })
          .width('100%')
          .padding({ left: space('3'), right: space('3'), top: space('2') })
      }

      if (this.success) {
        MulticaText({
          value: 'Saved',
          scheme: this.scheme,
          textSize: 'xs',
          color: 'success'
        })
          .width('100%')
          .padding({ left: space('3'), right: space('3'), top: space('2') })
      }

      Row() {
        MulticaButton({
          label: this.saving ? 'Saving...' : 'Save',
          scheme: this.scheme,
          variant: 'primary',
          fullWidth: true,
          disabled: this.saving,
          onTap: () => { void this.save(); }
        })
      }
      .width('100%')
      .padding({ left: space('3'), right: space('3'), top: space('2'), bottom: space('3') })
      .border({
        width: { top: 1 },
        color: String(themeTokens(this.scheme).border)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
