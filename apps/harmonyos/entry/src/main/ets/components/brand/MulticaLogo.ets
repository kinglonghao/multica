import { THEME, ColorScheme } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Multica brand mark. Plain-text rendering — we don't ship a
 * logo asset (M4) and a styled wordmark reads correctly in both
 * schemes. The icon dot is `ColorScheme.brand` so it tints
 * correctly under dark mode.
 */
@ComponentV2
export struct MulticaLogo {
  @Param scheme: ColorScheme = 'light';
  @Param size: 'sm' | 'md' | 'lg' = 'md';

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        Stack()
          .width(this.dotSize())
          .height(this.dotSize())
          .borderRadius(this.dotSize() / 2)
          .backgroundColor(String(THEME[this.scheme].brand))
      }
      .width(this.dotSize() + 4)
      .height(this.dotSize() + 4)
      .margin({ right: 6 })
      .alignItems(VerticalAlign.Center)
      .justifyContent(FlexAlign.Center)

      MulticaText({
        value: 'Multica',
        scheme: this.scheme,
        size: this.size === 'lg' ? 'xl' : this.size === 'sm' ? 'sm' : 'lg',
        weight: 'bold',
        color: 'foreground'
      })
    }
    .alignItems(VerticalAlign.Center)
  }

  private dotSize(): number {
    return this.size === 'lg' ? 14 : this.size === 'sm' ? 8 : 10;
  }
}
