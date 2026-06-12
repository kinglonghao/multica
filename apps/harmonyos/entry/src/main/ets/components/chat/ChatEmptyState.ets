import { ColorScheme, SPACE } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Empty state for the Chat tab. Centered stack with a glyph
 * and a call-to-action. The CTA button is rendered by the
 * parent so it can wire navigation.
 */
@ComponentV2
export struct ChatEmptyState {
  @Param scheme: ColorScheme = 'light';
  @Param title: string = '';
  @Param description: string = '';
  @BuilderParam action?: CustomBuilder;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: '💬',
          scheme: this.scheme,
          size: '3xl',
          textAlign: TextAlign.Center
        })
        MulticaText({
          value: this.title,
          scheme: this.scheme,
          size: 'lg',
          weight: 'semibold',
          color: 'foreground',
          textAlign: TextAlign.Center
        })
          .margin({ top: SPACE['3'] })
        if (this.description) {
          MulticaText({
            value: this.description,
            scheme: this.scheme,
            size: 'sm',
            color: 'mutedForeground',
            textAlign: TextAlign.Center
          })
            .margin({ top: SPACE['2'] })
        }
        if (this.action) {
          Column() { this.action?.() }
            .margin({ top: SPACE['4'] })
        }
      }
      .alignItems(HorizontalAlign.Center)
      .padding(SPACE['6'])
    }
    .layoutWeight(1)
    .width('100%')
  }
}
