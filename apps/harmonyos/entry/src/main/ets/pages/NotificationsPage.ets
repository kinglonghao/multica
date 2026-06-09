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

@Entry
@ComponentV2
struct NotificationsPage {
  @Local scheme: ColorScheme = 'light';
  @Local saving: boolean = false;
  @Local version: number = 0;
  private query: QueryHandle<NotificationPreferences> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useQuery<NotificationPreferences>(
      ['notification-prefs'],
      ({ signal }) => api.getNotificationPreferences({ signal }),
      { staleTimeMs: 60_000, onUpdate: () => { this.version++; } }
    );
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async save(): Promise<void> {
    const data = this.query?.getState().data;
    if (!data) return;
    this.saving = true;
    try {
      await api.updateNotificationPreferences(data);
    } catch (err) {
      console.warn('[notifications] save failed', err);
    } finally {
      this.saving = false;
    }
  }

  build() {
    Navigation(appNavigation.stack) {
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
            ForEach(state.data?.preferences ?? [], (pref: NotificationPreference) => {
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
                    pref.enabled = isOn;
                  })
              }
              .width('100%')
              .padding(SPACE['4'])
              .backgroundColor(String(THEME[this.scheme].card))
              .borderRadius(RADIUS.md)
              .margin({ top: SPACE['2'] })
            })
          }
          .padding(SPACE['4'])
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(THEME[this.scheme].background))
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
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
