import { ColorScheme, SPACE, textColor, THEME, RADIUS } from '../../lib/theme';
import { MarkdownBlock, InlineSpan, parseMarkdown } from '../../lib/markdown';

/**
 * Renders a markdown string as a sequence of `MulticaText` /
 * styled-`Text` blocks. Subset of the iOS client's
 * `react-native-enriched-markdown` surface: headings, code,
 * lists, links, plus inline `**bold**` / `*italic*` / `` `code` ``.
 *
 * Usage:
 *   Markdown({
 *     value: issue.description,
 *     scheme: this.scheme,
 *     onLinkPress: (url) => { /* open in browser *\/ }
 *   })
 *
 * The component is a pure renderer — it does NOT do any cache /
 * mutation / query work. The page that hosts it owns the source
 * string (typically from the issue-detail query).
 *
 * The output is a `Column` of styled children. Each block is
 * its own child so the layout is predictable (a heading always
 * sits in its own row with the right vertical spacing). Inline
 * spans within a paragraph are concatenated into a single
 * `Text` with multiple child spans, mirroring the
 * `Text`-composed-of-`TextSpan` ArkUI pattern.
 */
@ComponentV2
export struct Markdown {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  /** Optional click handler for `[text](url)` links. If unset,
   *  links render as styled text without a tap target. */
  @Param onLinkPress: (url: string) => void = (_url: string): void => {};

  build() {
    Column() {
      const blocks = parseMarkdown(this.value);
      ForEach(blocks, (b: MarkdownBlock, idx: number) => {
        if (b.type === 'heading') {
          this.Heading(b.level, b.spans)
        } else if (b.type === 'paragraph') {
          this.Paragraph(b.spans)
        } else if (b.type === 'code') {
          this.CodeBlock(b.language, b.value)
        } else if (b.type === 'list') {
          this.ListBlock(b.ordered, b.items)
        }
        if (idx < blocks.length - 1) {
          // Inter-block breathing room. Use a 1px transparent
          // spacer so the gap respects text-baseline alignment.
          Blank().height(SPACE['2'])
        }
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder Heading(level: 1 | 2 | 3, spans: InlineSpan[]) {
    Row() {
      this.Spans(spans, {
        size: level === 1 ? 'xl' : level === 2 ? 'lg' : 'md',
        weight: 'bold',
        color: 'foreground'
      })
    }
    .width('100%')
    .margin({ top: SPACE['3'], bottom: SPACE['1'] })
  }

  @Builder Paragraph(spans: InlineSpan[]) {
    Row() {
      this.Spans(spans, {
        size: 'sm',
        weight: 'normal',
        color: 'foreground'
      })
    }
    .width('100%')
  }

  @Builder CodeBlock(language: string, code: string) {
    Column() {
      if (language) {
        Text(language)
          .fontSize(11)
          .fontColor(textColor(this.scheme, 'mutedForeground'))
          .margin({ bottom: SPACE['1'] })
      }
      Text(code)
        .fontSize(12)
        .fontFamily('mono')
        .fontColor(textColor(this.scheme, 'foreground'))
        .padding(SPACE['3'])
        .backgroundColor(String(THEME[this.scheme].card))
        .borderRadius(RADIUS.md)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: SPACE['2'], bottom: SPACE['2'] })
  }

  @Builder ListBlock(ordered: boolean, items: InlineSpan[][]) {
    Column() {
      ForEach(items, (spans: InlineSpan[], i: number) => {
        Row() {
          Text(ordered ? `${i + 1}.` : '•')
            .fontSize(13)
            .fontColor(textColor(this.scheme, 'mutedForeground'))
            .width(ordered ? 24 : 16)
          this.Spans(spans, {
            size: 'sm',
            weight: 'normal',
            color: 'foreground'
          })
        }
        .width('100%')
        .margin({ top: i === 0 ? 0 : SPACE['1'] })
        .alignItems(VerticalAlign.Top)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .margin({ top: SPACE['1'], bottom: SPACE['1'] })
  }

  /**
   * Renders an inline-span list as a single composed `Text` with
   * child `TextSpan`s. ArkUI's `Text` accepts an array of
   * `TextSpanInterface` (string or styled span), which is the
   * idiomatic way to mix bold / italic / link styling in a
   * single text run.
   *
   * We resolve the base style (size / weight / color) and let
   * each span override as needed. A bold span flips weight to
   * `bold`; a link span uses `brand` color and the link click
   * handler.
   */
  @Builder Spans(spans: InlineSpan[], base: {
    size: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl';
    weight: 'normal' | 'medium' | 'semibold' | 'bold';
    color: 'foreground' | 'mutedForeground' | 'brand';
  }) {
    Text() {
      ForEach(spans, (s: InlineSpan) => {
        if (s.type === 'text') {
          Span(s.value)
            .fontSize(this.sizeOf(base.size))
            .fontWeight(this.weightOf(base.weight))
            .fontColor(textColor(this.scheme, base.color))
        } else if (s.type === 'bold') {
          Span(s.value)
            .fontSize(this.sizeOf(base.size))
            .fontWeight(this.weightOf('bold'))
            .fontColor(textColor(this.scheme, base.color))
        } else if (s.type === 'italic') {
          Span(s.value)
            .fontSize(this.sizeOf(base.size))
            .fontWeight(this.weightOf(base.weight))
            .fontStyle(FontStyle.Italic)
            .fontColor(textColor(this.scheme, base.color))
        } else if (s.type === 'code') {
          Span(s.value)
            .fontSize(this.sizeOf('xs'))
            .fontFamily('mono')
            .fontColor(textColor(this.scheme, 'foreground'))
            .backgroundColor(String(THEME[this.scheme].card))
        } else if (s.type === 'link') {
          Span(s.text)
            .fontSize(this.sizeOf(base.size))
            .fontWeight(this.weightOf(base.weight))
            .fontColor(textColor(this.scheme, 'brand'))
            .onClick(() => { this.onLinkPress(s.href); })
        }
      })
    }
    .width('100%')
  }

  private sizeOf(s: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl'): number {
    if (s === 'xs') return 11;
    if (s === 'sm') return 13;
    if (s === 'base') return 14;
    if (s === 'md') return 15;
    if (s === 'lg') return 17;
    return 20;
  }

  private weightOf(w: 'normal' | 'medium' | 'semibold' | 'bold'): number {
    if (w === 'normal') return 400;
    if (w === 'medium') return 500;
    if (w === 'semibold') return 600;
    return 700;
  }
}
