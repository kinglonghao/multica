import { THEME, ColorScheme, RADIUS, SPACE, space, themeTokens } from '../../lib/theme';

@ComponentV2
export struct Card {
  @Param scheme: ColorScheme = 'light';
  @BuilderParam content?: CustomBuilder;
  @Param contentPadding: number = space('3');
  @Param gap: number = space('2');

  build() {
    Column() {
      if (this.content) {
        this.content?.()
      }
    }
    .padding(this.contentPadding)
    .backgroundColor(String(themeTokens(this.scheme).card))
    .borderRadius(RADIUS.lg)
    .alignItems(HorizontalAlign.Start)
  }
}
