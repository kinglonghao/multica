import { THEME, ColorScheme, RADIUS } from '../../lib/theme';
import { MulticaText } from './Text';

@ComponentV2
export struct IconButton {
  @Param glyph: string = '·';
  @Param scheme: ColorScheme = 'light';
  @Param size: number = 36;
  @Param accessibilityLabel: string = '';
  @Event onTap: () => void = (): void => {};

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph,
        scheme: this.scheme,
        size: 'lg',
        weight: 'normal',
        color: 'foreground'
      })
    }
    .width(this.size)
    .height(this.size)
    .borderRadius(RADIUS.full)
    .backgroundColor('transparent')
    .onClick(() => { this.onTap(); })
    .accessibilityText(this.accessibilityLabel)
  }
}
