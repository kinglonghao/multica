import { THEME, ColorScheme } from '../../lib/theme';

@ComponentV2
export struct Separator {
  @Param scheme: ColorScheme = 'light';
  @Param orientation: 'horizontal' | 'vertical' = 'horizontal';

  build() {
    if (this.orientation === 'horizontal') {
      Divider()
        .width('100%')
        .height(1)
        .color(String(THEME[this.scheme].border))
    } else {
      Divider()
        .height('100%')
        .width(1)
        .vertical(true)
        .color(String(THEME[this.scheme].border))
    }
  }
}
