import { api } from '../data/api';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { NotificationPreferences, NotificationPreference } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';

const PREFS_QUERY_KEY: readonly string[] = ['notification-prefs', 'self'];
const PREFS_STALE_MS = 60_000;

class GroupMeta {
  label: string = '';
  description: string = '';
}

const GROUP_META: Map<string, GroupMeta> = new Map<string, GroupMeta>([
  ['assignments', (() => { const meta = new GroupMeta(); meta.label = 'Assignments'; meta.description = "When you're assigned an issue or removed as assignee."; return meta; })()],
  ['status_changes', (() => { const meta = new GroupMeta(); meta.label = 'Status changes'; meta.description = "When an issue's status changes."; return meta; })()],
  ['comments', (() => { const meta = new GroupMeta(); meta.label = 'Comments'; meta.description = "New comments on issues you're subscribed to."; return meta; })()],
  ['updates', (() => { const meta = new GroupMeta(); meta.label = 'Issue updates'; meta.description = 'Edits to title, description, labels, priority, or due date.'; return meta; })()],
  ['agent_activity', (() => { const meta = new GroupMeta(); meta.label = 'Agent activity'; meta.description = 'When an agent picks up, runs, or completes a task.'; return meta; })()],
  ['system_notifications', (() => { const meta = new GroupMeta(); meta.label = 'System notifications'; meta.description = 'Account changes, security alerts, product updates.'; return meta; })()]
]);

@ComponentV2
export struct NotificationsPage {
  @Local scheme: ColorScheme = 'light';
  @Local errorMessage: string = '';
  @Local version: number = 0;
  @Local _isLoading: boolean = true;
  @Local _data: NotificationPreferences | undefined = undefined;
  @Local _error: Error | null = null;
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

  private labelForCategory(category: string): string {
    const meta = GROUP_META.get(category);
    return meta ? meta.label : category;
  }

  private descriptionForCategory(category: string): string {
    const meta = GROUP_META.get(category);
    return meta ? meta.description : 'Notification setting';
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
        Column() {
          MulticaText({
            value: this._error.message.indexOf('404') >= 0 ? 'Notification settings are not available in this environment.' : 'Failed to load notification preferences.',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'semibold',
            textAlign: 'center',
            color: this._error.message.indexOf('404') >= 0 ? 'foreground' : 'destructive'
          })
          MulticaText({
            value: this._error.message.indexOf('404') >= 0
              ? 'The backend has not exposed notification preferences yet.'
              : this._error.message,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground',
            textAlign: 'center'
          })
            .margin({ top: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
        .padding(space('6'))
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.SectionHeader('Inbox notifications', 'Which events show up in your inbox.')
            Column() {
              ForEach(this.prefs, (pref: NotificationPreference, index?: number) => {
                Row() {
                  Column() {
                    MulticaText({
                      value: this.labelForCategory(pref.category),
                      scheme: this.scheme,
                      textSize: 'sm',
                      weight: 'medium',
                      color: 'foreground'
                    })
                    MulticaText({
                      value: this.descriptionForCategory(pref.category),
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
                .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
                .border((index ?? 0) < this.prefs.length - 1 ? {
                  width: { bottom: 1 },
                  color: String(themeTokens(this.scheme).border)
                } : undefined)
                .onClick(() => {
                  this.togglePref(index ?? 0, !pref.enabled);
                })
              })
            }
            .width('100%')
            .backgroundColor(String(themeTokens(this.scheme).card))
            .borderRadius(RADIUS.xl)
            .border({ width: 1, color: String(themeTokens(this.scheme).border) })
          }
          .width('100%')
          .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder SectionHeader(title: string, description: string) {
    Column() {
      MulticaText({
        value: title,
        scheme: this.scheme,
        textSize: 'xs',
        color: 'mutedForeground',
        weight: 'semibold'
      })
      MulticaText({
        value: description,
        scheme: this.scheme,
        textSize: 'xs',
        color: 'mutedForeground'
      })
        .margin({ top: 4 })
    }
    .margin({ left: space('1'), bottom: space('2') })
    .alignItems(HorizontalAlign.Start)
  }
}
