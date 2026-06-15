import { ColorScheme, RADIUS, space, themeTokens } from '../../lib/theme';
import { stripMarkdownForDisplay } from '../../lib/utils';
import { MulticaText } from './Text';

interface MarkdownBlock {
  kind: 'heading' | 'quote' | 'bullet' | 'paragraph' | 'code';
  text: string;
}

@ComponentV2
export struct MarkdownText {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param compact: boolean = false;

  build() {
    Column({ space: this.compact ? space('1.5') : space('2') }) {
      ForEach(this.blocks(), (block: MarkdownBlock, index: number) => {
        this.Block(block, index)
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder Block(block: MarkdownBlock, index: number) {
    if (block.kind === 'heading') {
      MulticaText({
        value: block.text,
        scheme: this.scheme,
        textSize: this.compact ? 'md' : 'lg',
        weight: 'bold',
        color: 'foreground'
      })
        .width('100%')
    } else if (block.kind === 'quote') {
      Row() {
        Column() {}
          .width(3)
          .height('100%')
          .backgroundColor(String(themeTokens(this.scheme).border))
          .borderRadius(RADIUS.full)
        MulticaText({
          value: block.text,
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'mutedForeground'
        })
          .margin({ left: space('3') })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === 'bullet') {
      Row() {
        MulticaText({
          value: '•',
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'foreground',
          weight: 'medium'
        })
          .margin({ top: 1 })
        MulticaText({
          value: block.text,
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'foreground'
        })
          .margin({ left: space('2') })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === 'code') {
      Column() {
        MulticaText({
          value: block.text,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'foreground'
        })
          .width('100%')
      }
      .width('100%')
      .padding(space('3'))
      .backgroundColor(String(themeTokens(this.scheme).background))
      .borderRadius(RADIUS.md)
    } else {
      MulticaText({
        value: block.text,
        scheme: this.scheme,
        textSize: this.compact ? 'sm' : 'base',
        color: 'foreground'
      })
        .width('100%')
    }
  }

  private blocks(): MarkdownBlock[] {
    const raw = this.value ?? '';
    if (!raw.trim()) return [];
    const lines = raw.replace(/\r\n/g, '\n').split('\n');
    const out: MarkdownBlock[] = [];
    let inCode = false;
    let codeBuffer = '';

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        if (inCode) {
          out.push({ kind: 'code', text: codeBuffer.trim() });
          codeBuffer = '';
          inCode = false;
        } else {
          inCode = true;
          codeBuffer = '';
        }
        continue;
      }

      if (inCode) {
        codeBuffer += (codeBuffer ? '\n' : '') + line;
        continue;
      }

      if (!trimmed) {
        continue;
      }

      if (trimmed.startsWith('#')) {
        out.push({ kind: 'heading', text: stripMarkdownForDisplay(trimmed) });
        continue;
      }

      if (trimmed.startsWith('>')) {
        out.push({ kind: 'quote', text: stripMarkdownForDisplay(trimmed) });
        continue;
      }

      if (/^[-*+]\s+/.test(trimmed) || /^\d+\.\s+/.test(trimmed)) {
        out.push({ kind: 'bullet', text: stripMarkdownForDisplay(trimmed).replace(/^•\s*/, '') });
        continue;
      }

      out.push({ kind: 'paragraph', text: stripMarkdownForDisplay(trimmed) });
    }

    if (inCode && codeBuffer.trim()) {
      out.push({ kind: 'code', text: codeBuffer.trim() });
    }

    return out;
  }
}
