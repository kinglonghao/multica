import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Multi-line message composer used at the bottom of chat
 * sessions. Wraps a TextArea + send button; emits the typed
 * value through the parent's two-way binding. Draft
 * persistence lives in the parent page — this component is
 * a pure presentational input.
 */
@ComponentV2
export struct ChatComposer {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param placeholder: string = 'Message…';
  @Param sending: boolean = false;
  @Param disabled: boolean = false;
  @Event onChange: (v: string) => void = (_v: string): void => {};
  @Event onSend: () => void = (): void => {};

  build() {
    Row() {
      TextArea({ placeholder: this.placeholder, text: this.value })
        .placeholderColor(String(THEME[this.scheme].mutedForeground))
        .fontColor(String(THEME[this.scheme].foreground))
        .backgroundColor(String(THEME[this.scheme].card))
        .borderRadius(RADIUS.lg)
        .padding(SPACE['3'])
        .layoutWeight(1)
        .constraintSize({ minHeight: 40, maxHeight: 120 })
        .onChange((value: string) => { this.onChange(value); })
        .enabled(!this.disabled)
        .opacity(this.disabled ? 0.6 : 1)

      MulticaText({
        value: this.sending ? '…' : '↑',
        scheme: this.scheme,
        size: 'xl',
        weight: 'bold',
        color: this.canSend() ? 'brand' : 'mutedForeground'
      })
        .width(40)
        .height(40)
        .borderRadius(RADIUS.full)
        .backgroundColor(this.canSend() ? String(THEME[this.scheme].card) : 'transparent')
        .margin({ left: SPACE['2'] })
        .textAlign(TextAlign.Center)
        .onClick(() => {
          if (this.canSend()) this.onSend();
        })
    }
    .width('100%')
    .padding(SPACE['3'])
    .border({
      width: { top: 1 },
      color: String(THEME[this.scheme].border)
    })
  }

  private canSend(): boolean {
    return !this.sending && !this.disabled && this.value.trim().length > 0;
  }
}
