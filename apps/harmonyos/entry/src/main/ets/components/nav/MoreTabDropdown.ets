import { ColorScheme, SPACE, RADIUS, THEME } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

interface DropdownItem {
  key: string;
  label: string;
}

/**
 * Lightweight dropdown used in the chat header for switching
 * between chat sessions, and as a generic `More` menu primitive.
 * Renders the trigger as a row that shows the current value +
 * a chevron. Tapping opens an overlay list below; tapping an
 * item emits `onSelect(key)`. The host page wires the open
 * state via `@Param open` so the page can dismiss via outside
 * tap.
 */
@ComponentV2
export struct MoreTabDropdown {
  @Param open: boolean = false;
  @Param items: DropdownItem[] = [];
  @Param value: string = '';
  @Param placeholder: string = 'Select…';
  @Param scheme: ColorScheme = 'light';
  @Event onOpen: () => void = (): void => {};
  @Event onClose: () => void = (): void => {};
  @Event onSelect: (key: string) => void = (_k: string): void => {};

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Row() {
        MulticaText({
          value: this.value || this.placeholder,
          scheme: this.scheme,
          size: 'sm',
          weight: 'medium',
          color: this.value ? 'foreground' : 'mutedForeground'
        })
        Blank()
        MulticaText({
          value: this.open ? '▲' : '▼',
          scheme: this.scheme,
          size: 'xs',
          color: 'mutedForeground'
        })
      }
      .width('100%')
      .padding(SPACE['3'])
      .borderRadius(RADIUS.md)
      .backgroundColor(String(THEME[this.scheme].card))
      .border({
        width: 1,
        color: String(THEME[this.scheme].border)
      })
      .onClick(() => {
        if (this.open) { this.onClose(); } else { this.onOpen(); }
      })

      if (this.open) {
        Column() {
          ForEach(this.items, (item: DropdownItem) => {
            Row() {
              MulticaText({
                value: item.label,
                scheme: this.scheme,
                size: 'sm',
                color: 'foreground'
              })
            }
            .width('100%')
            .padding(SPACE['3'])
            .backgroundColor(String(THEME[this.scheme].background))
            .onClick(() => { this.onSelect(item.key); })
            .divider({ strokeWidth: 1, color: String(THEME[this.scheme].border) })
          })
        }
        .width('100%')
        .margin({ top: 44 })
        .borderRadius(RADIUS.md)
        .backgroundColor(String(THEME[this.scheme].background))
        .border({
          width: 1,
          color: String(THEME[this.scheme].border)
        })
        .zIndex(10)
      }
    }
    .width('100%')
  }
}
