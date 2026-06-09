import { THEME, ColorScheme, SPACE, FONT_SIZE, FONT_WEIGHT } from '../../lib/theme';
import { MulticaText } from './Text';

@Component
export struct Header {
  @Prop title: string = '';
  @Prop scheme: ColorScheme = 'light';
  @BuilderParam left?: CustomBuilder;
  @BuilderParam right?: CustomBuilder;

  build() {
    Row() {
      if (this.left) {
        Row() { this.left?.() }
          .margin({ right: SPACE['2'] })
      }
      MulticaText({
        value: this.title,
        scheme: this.scheme,
        size: 'lg',
        weight: 'semibold',
        color: 'foreground'
      })
      Blank()
      if (this.right) {
        Row() { this.right?.() }
      }
    }
    .width('100%')
    .padding({
      left: SPACE['4'],
      right: SPACE['4'],
      top: SPACE['3'],
      bottom: SPACE['3']
    })
    .backgroundColor(String(THEME[this.scheme].background))
    .border({
      width: { bottom: 1 },
      color: String(THEME[this.scheme].border)
    })
    .constraintSize({ minHeight: 56 })
    .alignItems(VerticalAlign.Center)
  }
}
