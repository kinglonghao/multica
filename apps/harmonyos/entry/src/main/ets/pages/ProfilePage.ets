import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { api } from '../data/api';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
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
    return 'light';
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
      Header({
        title: 'Profile',
        scheme: this.scheme,
        left: this.BackButton()
      })

      Scroll() {
        Column() {
          Row() {
            Avatar({ name: this.displayName || this.email, url: '', avatarSize: 64, scheme: this.scheme })
            Column() {
              MulticaText({
                value: this.displayName || this.email,
                scheme: this.scheme,
                textSize: 'base',
                weight: 'medium',
                color: 'foreground'
              })
              MulticaText({
                value: this.email,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
                .margin({ top: space('0.5') })
            }
            .layoutWeight(1)
            .margin({ left: space('3') })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding(space('4'))
          .alignItems(VerticalAlign.Center)

          MulticaText({
            value: 'Display name',
            scheme: this.scheme,
            textSize: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
            .width('100%')
            .margin({ top: space('2') })

          TextInput({ placeholder: 'Display name', text: this.displayName })
            .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
            .fontColor(String(themeTokens(this.scheme).foreground))
            .backgroundColor(String(themeTokens(this.scheme).card))
            .borderRadius(RADIUS.md)
            .padding(space('3'))
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
              textSize: 'sm',
              color: 'destructive'
            })
              .margin({ top: space('2') })
          }

          if (this.success) {
            MulticaText({
              value: 'Profile updated',
              scheme: this.scheme,
              textSize: 'sm',
              color: 'success'
            })
              .margin({ top: space('2') })
          }

          MulticaButton({
            label: this.saving ? 'Saving…' : 'Save',
            scheme: this.scheme,
            variant: 'primary',
            fullWidth: true,
            disabled: this.saving,
            onTap: () => { void this.save(); }
          })
            .margin({ top: space('4') })
        }
        .padding(space('4'))
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
