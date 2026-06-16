import { appNavigation, navParam } from '../data/navigation';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { MulticaButton } from '../components/ui/Button';

@ComponentV2
export struct LoginPage {
  @Local email: string = '';
  @Local loading: boolean = false;
  @Local errorMessage: string = '';
  @Local scheme: ColorScheme = 'light';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private isValidEmail(email: string): boolean {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
  }

  private async sendCode(): Promise<void> {
    if (!this.isValidEmail(this.email)) {
      this.errorMessage = 'Please enter a valid email address';
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      await authStore.requestOtp(this.email);
      appNavigation.pushName('VerifyPage', navParam('email', this.email));
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Failed to send code';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: 'Welcome to Multica',
          scheme: this.scheme,
          textSize: '2xl',
          weight: 'bold',
          color: 'foreground'
        })
        MulticaText({
          value: 'Enter your email to receive a sign-in code',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'mutedForeground',
          textAlign: 'center'
        })
          .margin({ top: space('2') })

        TextInput({ placeholder: 'you@example.com', text: this.email })
          .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
          .fontColor(String(themeTokens(this.scheme).foreground))
          .backgroundColor(String(themeTokens(this.scheme).card))
          .borderRadius(RADIUS.md)
          .padding(space('3'))
          .width('100%')
          .margin({ top: space('8') })
          .type(InputType.Email)
          .onChange((value: string) => {
            this.email = value;
            this.errorMessage = '';
          })

        if (this.errorMessage) {
          MulticaText({
            value: this.errorMessage,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'destructive'
          })
            .margin({ top: space('2') })
            .width('100%')
        }

        MulticaButton({
          label: this.loading ? 'Sending…' : 'Send sign-in code',
          scheme: this.scheme,
          variant: 'primary',
          fullWidth: true,
          disabled: this.loading,
          onTap: () => { void this.sendCode(); }
        })
          .margin({ top: space('4') })
      }
      .width('100%')
      .padding(space('6'))
      .constraintSize({ maxWidth: 480 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
