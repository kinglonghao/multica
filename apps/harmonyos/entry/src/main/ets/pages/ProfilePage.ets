import { appNavigation } from '../data/navigation';
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
    this.displayName = user?.display_name ?? '';
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
      await api.updateMe({ display_name: this.displayName });
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
            Row() {
              Avatar({ name: this.displayName || this.email, url: '', avatarSize: 52, scheme: this.scheme })
              Column() {
                MulticaText({
                  value: this.displayName || this.email,
                  scheme: this.scheme,
                  textSize: 'sm',
                  weight: 'semibold',
                  color: 'foreground'
                })
                MulticaText({
                  value: this.email,
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'mutedForeground'
                })
                  .margin({ top: 3 })
              }
              .layoutWeight(1)
              .margin({ left: space('3') })
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')
          }
          .width('100%')
          .padding(space('3'))
          .margin({ top: space('3') })
          .backgroundColor(String(themeTokens(this.scheme).background))
          .borderRadius(RADIUS.lg)
          .border({ width: 1, color: String(themeTokens(this.scheme).border) })

          Column() {
            MulticaText({
              value: 'Display name',
              scheme: this.scheme,
              textSize: 'xs',
              weight: 'semibold',
              color: 'mutedForeground'
            })
            TextInput({ placeholder: 'Display name', text: this.displayName })
              .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
              .fontColor(String(themeTokens(this.scheme).foreground))
              .backgroundColor(String(themeTokens(this.scheme).background))
              .borderRadius(RADIUS.md)
              .padding({ left: space('3'), right: space('3'), top: space('2.5'), bottom: space('2.5') })
              .width('100%')
              .margin({ top: space('2') })
              .onChange((value: string) => {
                this.displayName = value;
                this.success = false;
              })

            if (this.errorMessage) {
              MulticaText({
                value: this.errorMessage,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'destructive'
              })
                .margin({ top: space('2') })
            }

            if (this.success) {
              MulticaText({
                value: 'Saved',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'success'
              })
                .margin({ top: space('2') })
            }
          }
          .width('100%')
          .padding(space('3'))
          .margin({ top: space('3') })
          .backgroundColor(String(themeTokens(this.scheme).background))
          .borderRadius(RADIUS.lg)
          .border({ width: 1, color: String(themeTokens(this.scheme).border) })
          .alignItems(HorizontalAlign.Start)

          MulticaButton({
            label: this.saving ? 'Saving...' : 'Save',
            scheme: this.scheme,
            variant: 'primary',
            fullWidth: true,
            disabled: this.saving,
            onTap: () => { void this.save(); }
          })
            .margin({ left: space('3'), right: space('3'), top: space('4') })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
