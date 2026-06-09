import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { MulticaButton } from '../components/ui/Button';

@ComponentV2
export struct VerifyPage {
  @Local email: string = '';
  @Local code: string = '';
  @Local loading: boolean = false;
  @Local errorMessage: string = '';
  @Local scheme: ColorScheme = 'light';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    // Read the email param from the top of the NavPathStack. We
    // previously relied on `@Param initialEmail` set by the destination
    // builder, but in practice the @Param prop didn't bind reliably
    // when the parent is a @Builder function (the @Builder may not
    // own the lifecycle that V2's prop binding expects). Reading
    // directly from the stack is the official API path and the one
    // that always reflects the param the caller pushed.
    this.email = appNavigation.readString('VerifyPage', 'email', '');
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async verify(): Promise<void> {
    if (this.code.length !== 6) {
      this.errorMessage = 'Please enter the 6-digit code';
      return;
    }
    this.loading = true;
    this.errorMessage = '';
    try {
      await authStore.verifyOtp(this.email, this.code);
      // Bug 3 fix: clear the destination stack and let the root
      // WorkspaceLayout re-render with the now-authed state. Using
      // replaceName('WorkspaceLayout') was a no-op because
      // WorkspaceLayout isn't in the destination builder.
      appNavigation.clearStack();
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Verification failed';
    } finally {
      this.loading = false;
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: 'Enter verification code',
          scheme: this.scheme,
          size: 'xl',
          weight: 'bold',
          color: 'foreground'
        })
        MulticaText({
          value: `Sent to ${this.email}`,
          scheme: this.scheme,
          size: 'sm',
          color: 'mutedForeground'
        })
          .margin({ top: SPACE['2'] })

        TextInput({ placeholder: '000000', text: this.code })
          .placeholderColor(String(THEME[this.scheme].mutedForeground))
          .fontColor(String(THEME[this.scheme].foreground))
          .backgroundColor(String(THEME[this.scheme].card))
          .borderRadius(RADIUS.md)
          .padding(SPACE['3'])
          .width('100%')
          .margin({ top: SPACE['8'] })
          .type(InputType.Number)
          .maxLength(6)
          .fontSize(24)
          .textAlign(TextAlign.Center)
          .onChange((value: string) => {
            this.code = value;
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
        }

        MulticaButton({
          label: this.loading ? 'Verifying…' : 'Verify',
          scheme: this.scheme,
          variant: 'primary',
          fullWidth: true,
          disabled: this.loading,
          onTap: () => { void this.verify(); }
        })
          .margin({ top: SPACE['4'] })

        MulticaButton({
          label: 'Back',
          scheme: this.scheme,
          variant: 'ghost',
          fullWidth: true,
          onTap: () => { appNavigation.pop(); }
        })
          .margin({ top: SPACE['2'] })
      }
      .width('100%')
      .padding(SPACE['6'])
      .constraintSize({ maxWidth: 480 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
