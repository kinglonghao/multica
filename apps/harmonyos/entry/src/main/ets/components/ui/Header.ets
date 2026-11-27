import { THEME, ColorScheme, SPACE, space, themeTokens } from '../../lib/theme';
import { MulticaText } from './Text';

@ComponentV2
export struct Header {
  @Param title: string = '';
  @Param scheme: ColorScheme = 'light';
  @BuilderParam left?: CustomBuilder;
  @BuilderParam right?: CustomBuilder;

  build() {
    Row() {
      if (this.left) {
        Row() { this.left?.() }
          .margin({ right: space('2') })
      }
      MulticaText({
        value: this.title,
        scheme: this.scheme,
        textSize: 'lg',
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
      left: space('4'),
      right: space('4'),
      top: 54,
      bottom: space('3')
    })
    .constraintSize({ minHeight: 88 })
    .alignItems(VerticalAlign.Center)
  }
}
