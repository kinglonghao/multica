import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Generic single-line composer used by the new-issue form's
 * title field and other short-input contexts. Backed by
 * TextInput (not TextArea) because title fields are short.
 * The parent supplies the onChange binding.
 */
@ComponentV2
export struct MessageComposer {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param placeholder: string = '';
  @Param disabled: boolean = false;
  @Event onChange: (v: string) => void = (_v: string): void => {};

  build() {
    TextInput({ placeholder: this.placeholder, text: this.value })
      .placeholderColor(String(THEME[this.scheme].mutedForeground))
      .fontColor(String(THEME[this.scheme].foreground))
      .backgroundColor(String(THEME[this.scheme].card))
      .borderRadius(RADIUS.md)
      .padding(SPACE['3'])
      .width('100%')
      .onChange((value: string) => { this.onChange(value); })
      .enabled(!this.disabled)
      .opacity(this.disabled ? 0.6 : 1)
  }
}
