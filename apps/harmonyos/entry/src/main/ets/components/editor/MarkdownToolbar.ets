import { ColorScheme, SPACE, RADIUS, THEME } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

interface ToolbarItem {
  key: 'bold' | 'italic' | 'code' | 'link' | 'list' | 'quote' | 'heading' | 'attach';
  glyph: string;
  label: string;
}

/**
 * Minimal markdown formatting toolbar. Used by the New Issue
 * page and any future rich-text editor surface. Tapping a
 * toolbar item emits `onAction(key)`; the parent decides what
 * to do (insert markdown at the cursor, open the attachment
 * picker, etc.) so this component stays text-agnostic.
 */
@ComponentV2
export struct MarkdownToolbar {
  @Param scheme: ColorScheme = 'light';
  @Param items: ToolbarItem[] = [
    { key: 'bold', glyph: 'B', label: 'Bold' },
    { key: 'italic', glyph: 'I', label: 'Italic' },
    { key: 'code', glyph: '<>', label: 'Code' },
    { key: 'link', glyph: '🔗', label: 'Link' },
    { key: 'list', glyph: '•', label: 'List' },
    { key: 'quote', glyph: '“', label: 'Quote' },
    { key: 'heading', glyph: 'H', label: 'Heading' },
    { key: 'attach', glyph: '📎', label: 'Attach' }
  ];
  @Event onAction: (key: ToolbarItem['key']) => void = (_k: ToolbarItem['key']): void => {};

  build() {
    Row() {
      ForEach(this.items, (item: ToolbarItem) => {
        this.Item(item)
      })
    }
    .width('100%')
    .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['1'], bottom: SPACE['1'] })
    .border({
      width: { top: 1, bottom: 1 },
      color: String(THEME[this.scheme].border)
    })
  }

  @Builder Item(item: ToolbarItem) {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: item.glyph,
        scheme: this.scheme,
        size: 'sm',
        weight: item.key === 'bold' || item.key === 'heading' ? 'bold' : 'medium',
        color: 'foreground'
      })
    }
    .width(36)
    .height(36)
    .borderRadius(RADIUS.sm)
    .margin({ left: SPACE['1'], right: SPACE['1'] })
    .onClick(() => { this.onAction(item.key); })
    .accessibilityText(item.label)
  }
}
