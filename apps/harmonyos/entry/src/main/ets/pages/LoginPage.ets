import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { MulticaButton } from '../components/ui/Button';

@Entry
@ComponentV2
struct LoginPage {
  @Local email: string = '';
  @Local loading: boolean = false;
  @Local errorMessage: string = '';
  @Local scheme: ColorScheme = 'light';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
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
      appNavigation.pushName('VerifyPage', { email: this.email });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Failed to send code';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Navigation(appNavigation.stack) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          MulticaText({
            value: 'Welcome to Multica',
            scheme: this.scheme,
            size: '2xl',
            weight: 'bold',
            color: 'foreground'
          })
          MulticaText({
            value: 'Enter your email to receive a sign-in code',
            scheme: this.scheme,
            size: 'sm',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['2'] })
            .textAlign(TextAlign.Center)

          TextInput({ placeholder: 'you@example.com', text: this.email })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['8'] })
            .type(InputType.Email)
            .onChange((value: string) => {
              this.email = value;
              this.errorMessage = '';
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

          MulticaButton({
            label: this.loading ? 'Sending…' : 'Send sign-in code',
            scheme: this.scheme,
            variant: 'primary',
            fullWidth: true,
            disabled: this.loading,
            onTap: () => { void this.sendCode(); }
          })
            .margin({ top: SPACE['4'] })
        }
        .width('100%')
        .padding(SPACE['6'])
        .constraintSize({ maxWidth: 480 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(THEME[this.scheme].background))
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}
