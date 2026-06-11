import { ColorScheme, SPACE, THEME, RADIUS, textColor } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Single-select picker row. Renders a labelled option inside a
 * list with a leading check icon when the row is the current
 * value. The component is intentionally a pure renderer — the
 * caller owns the value / onChange closure and the source of
 * the option list.
 *
 * Why a shared component: the status / priority pickers on the
 * issue detail page and the project detail page share the same
 * row shape. Pulling it out stops the "tap → background flashes
 * because the row was rendered differently" inconsistency that
 * the inline rows in v0.1 had.
 */
@ComponentV2
export struct PickerRow {
  @Param label: string = '';
  @Param selected: boolean = false;
  @Param scheme: ColorScheme = 'light';
  @Param leadingIcon?: CustomBuilder;
  @Param onTap: () => void = (): void => {};

  build() {
    Row() {
      if (this.leadingIcon) {
        Row() { this.leadingIcon?.() }
          .margin({ right: SPACE['3'] })
      }
      MulticaText({
        value: this.label,
        scheme: this.scheme,
        size: 'base',
        color: 'foreground'
      })
      Blank()
      if (this.selected) {
        Text('✓')
          .fontSize(18)
          .fontColor(textColor(this.scheme, 'brand'))
      }
    }
    .width('100%')
    .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
    .backgroundColor(
      this.selected
        ? String(THEME[this.scheme].card)
        : String(THEME[this.scheme].background)
    )
    .borderRadius(RADIUS.md)
    .onClick(() => { this.onTap(); })
  }
}
