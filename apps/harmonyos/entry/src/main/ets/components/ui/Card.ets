import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';

@ComponentV2
export struct Card {
  @Param scheme: ColorScheme = 'light';
  @BuilderParam content?: CustomBuilder;
  @Param padding: number = SPACE['3'];
  @Param gap: number = SPACE['2'];

  build() {
    Column() {
      if (this.content) {
        this.content?.()
      }
    }
    .padding(this.padding)
    .backgroundColor(String(THEME[this.scheme].card))
    .borderRadius(RADIUS.lg)
    .alignItems(HorizontalAlign.Start)
  }
}
