import { THEME, ColorScheme, SPACE, RADIUS } from '../../lib/theme';
import { MulticaText } from './Text';

@Component
export struct IconButton {
  @Prop glyph: string = '·';
  @Prop scheme: ColorScheme = 'light';
  @Prop size: number = 36;
  @Prop accessibilityLabel: string = '';
  onTap: () => void = () => {};

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
