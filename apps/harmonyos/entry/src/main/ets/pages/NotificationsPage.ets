import router from '@ohos.router';
import { api } from '../data/api';
import { useQuery } from '../queries/cache';
import { NotificationPreferences, NotificationPreference } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Skeleton } from '../components/ui/Skeleton';
import { MulticaButton } from '../components/ui/Button';

@Entry
@Component
struct NotificationsPage {
  @State scheme: ColorScheme = 'light';
  @State prefs: NotificationPreference[] = [];
  @State saving: boolean = false;
  @State loaded: boolean = false;
  private query = useQuery<NotificationPreferences>(
    ['notification-prefs'],
    ({ signal }) => api.getNotificationPreferences({ signal }),
    { staleTimeMs: 60_000 }
  );

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({
        title: 'Notifications',
        scheme: this.scheme,
        left: this.BackButton(),
        right: this.SaveButton()
      })

      if (this.query.state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Skeleton({ scheme: this.scheme, width: '90%', height: 56, radius: 8 })
              .margin({ top: SPACE['3'] })
          })
        }
        .padding(SPACE['4'])
      } else {
        Column() {
          ForEach(this.query.state.data?.preferences ?? [], (pref: NotificationPreference) => {
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

  private async save(): Promise<void> {
    const data = this.query.state.data;
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

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { router.back(); }
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
