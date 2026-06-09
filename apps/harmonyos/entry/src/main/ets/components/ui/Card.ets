import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';

@Component
export struct Card {
  @Prop scheme: ColorScheme = 'light';
  @BuilderParam content?: CustomBuilder;
  @Prop padding: number = SPACE['3'];
  @Prop gap: number = SPACE['2'];

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
