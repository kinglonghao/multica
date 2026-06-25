import { authStore } from '../data/auth';
import { api } from '../data/api';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Avatar } from '../components/ui/Avatar';
import { MulticaButton } from '../components/ui/Button';

@ComponentV2
export struct ProfilePage {
  @Local scheme: ColorScheme = 'light';
  @Local displayName: string = '';
  @Local email: string = '';
  @Local saving: boolean = false;
  @Local errorMessage: string = '';
  @Local success: boolean = false;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const user = authStore.getState().user;
    this.displayName = user?.display_name ?? user?.email ?? '';
    this.email = user?.email ?? '';
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private async save(): Promise<void> {
    this.saving = true;
    this.errorMessage = '';
    this.success = false;
    try {
      await api.updateMe({ display_name: this.displayName.trim() });
      this.success = true;
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Failed to update profile';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column() {
            Avatar({ name: this.displayName || this.email, url: '', avatarSize: 96, scheme: this.scheme })

            MulticaText({
              value: this.saving ? 'Saving profile…' : 'Tap to change photo',
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground'
            })
              .margin({ top: space('3') })
          }
          .width('100%')
          .padding({ top: space('6') })
          .alignItems(HorizontalAlign.Center)

          Row() {}
            .width('100%')
            .height(1)
            .margin({ top: space('6') })
            .backgroundColor(String(themeTokens(this.scheme).border))

          Column() {
            Column() {
              MulticaText({
                value: 'Name',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
              TextInput({ placeholder: 'Your name', text: this.displayName })
                .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
                .fontColor(String(themeTokens(this.scheme).foreground))
                .backgroundColor('#FFFFFF')
                .borderRadius(RADIUS.md)
                .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
                .margin({ top: space('2') })
                .border({ width: 1, color: String(themeTokens(this.scheme).border) })
                .onChange((value: string) => {
                  this.displayName = value;
                  this.success = false;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column() {
              MulticaText({
                value: 'Email',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
              Row() {
                MulticaText({
                  value: this.email || '—',
                  scheme: this.scheme,
                  textSize: 'sm',
                  color: 'mutedForeground'
                })
              }
              .width('100%')
              .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
              .margin({ top: space('2') })
              .backgroundColor('#F4F4F5')
              .borderRadius(RADIUS.md)
              .border({ width: 1, color: '#ECECF1' })

              MulticaText({
                value: 'Email is set at sign-up and can’t be changed here.',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
                .margin({ top: space('2') })
            }
            .width('100%')
            .margin({ top: space('4') })
            .alignItems(HorizontalAlign.Start)

            if (this.errorMessage) {
              MulticaText({
                value: this.errorMessage,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'destructive'
              })
                .margin({ top: space('3') })
            }

            if (this.success) {
              MulticaText({
                value: 'Saved',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'success'
              })
                .margin({ top: space('3') })
            }
          }
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('6'), bottom: space('8') })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Row() {
        MulticaButton({
          label: this.saving ? 'Saving…' : 'Save',
          scheme: this.scheme,
          variant: 'primary',
          fullWidth: true,
          disabled: this.saving,
          onTap: () => { void this.save(); }
        })
      }
      .width('100%')
      .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('4') })
      .backgroundColor(String(themeTokens(this.scheme).background))
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
