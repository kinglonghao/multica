import { THEME, ColorScheme, RADIUS } from '../../lib/theme';
import { MulticaText } from './Text';

@ComponentV2
export struct IconButton {
  @Param glyph: string = '·';
  @Param scheme: ColorScheme = 'light';
  @Param iconButtonSize: number = 36;
  @Param accessibilityLabel: string = '';
  @Event onTap: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph,
        scheme: this.scheme,
        textSize: 'lg',
        weight: 'normal',
        color: 'foreground'
      })
    }
    .width(this.iconButtonSize)
    .height(this.iconButtonSize)
    .borderRadius(RADIUS.full)
    .backgroundColor('transparent')
    .onClick(() => { this.onTap(); })
    .accessibilityText(this.accessibilityLabel)
  }
}
