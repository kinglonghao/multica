import { THEME, ColorScheme } from '../../lib/theme';

@Component
export struct Separator {
  @Prop scheme: ColorScheme = 'light';
  @Prop orientation: 'horizontal' | 'vertical' = 'horizontal';

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
