import { textColor, fontSize, fontWeight } from '../../lib/theme';
import { ColorScheme, RADIUS, space, themeTokens } from '../../lib/theme';
import { stripMarkdownForDisplay } from '../../lib/utils';
import { MulticaText } from './Text';

interface InlineSegment {
  text: string;
  bold: boolean;
}

interface MarkdownTable {
  headers: string[];
  rows: string[][];
}

interface MarkdownBlock {
  kind: 'heading' | 'quote' | 'bullet' | 'task' | 'paragraph' | 'code' | 'table' | 'divider';
  text: string;
  level?: number;
  ordered?: boolean;
  marker?: string;
  language?: string;
  checked?: boolean;
  table?: MarkdownTable;
}

@ComponentV2
export struct MarkdownText {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param compact: boolean = false;

  build() {
    Column({ space: this.compact ? space('1.5') : space('2.5') }) {
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
        textSize: this.headingSize(block.level ?? 1),
        weight: 'bold',
        color: 'foreground'
      })
        .width('100%')
    } else if (block.kind === 'quote') {
      Row() {
        Column() {}
          .width(3)
          .height(this.compact ? 22 : 24)
          .margin({ top: 2 })
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
      .padding({ top: space('1'), bottom: space('1') })
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === 'bullet') {
      Row() {
        MulticaText({
          value: block.ordered ? `${block.marker ?? '1.'}` : '•',
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'foreground',
          weight: 'medium'
        })
          .width(block.ordered ? 30 : 16)
          .margin({ top: 1 })
        MulticaText({
          value: block.text,
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'foreground'
        })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === 'task') {
      Row() {
        MulticaText({
          value: block.checked ? '☑' : '☐',
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: block.checked ? 'brand' : 'mutedForeground',
          weight: 'medium'
        })
          .width(20)
          .margin({ top: 1 })
        MulticaText({
          value: block.text,
          scheme: this.scheme,
          textSize: this.compact ? 'sm' : 'base',
          color: 'foreground'
        })
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else if (block.kind === 'code') {
      Column({ space: 0 }) {
        if (block.language && block.language.trim().length > 0) {
          Row() {
            MulticaText({
              value: block.language,
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground',
              weight: 'medium'
            })
            Blank()
          }
          .width('100%')
          .padding({ left: space('3'), right: space('3'), top: space('2'), bottom: space('2') })
          .backgroundColor(String(this.codeHeaderBackground()))
          .border({ width: { bottom: 1 }, color: String(themeTokens(this.scheme).border) })
        }
        Scroll() {
          Text(block.text)
            .fontSize(this.compact ? 12 : 13)
            .fontColor(String(themeTokens(this.scheme).foreground))
            .fontFamily('monospace')
            .lineHeight(this.compact ? 18 : 20)
            .textAlign(TextAlign.Start)
        }
        .width('100%')
        .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
        .backgroundColor(String(this.codeBodyBackground()))
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Auto)
      }
      .width('100%')
      .clip(true)
      .borderRadius(RADIUS.md)
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
    } else if (block.kind === 'table' && block.table) {
      this.TableBlock(block.table)
    } else if (block.kind === 'divider') {
      Column() {}
        .width('100%')
        .height(1)
        .backgroundColor(String(themeTokens(this.scheme).border))
        .margin({ top: this.compact ? space('1') : space('2'), bottom: this.compact ? space('1') : space('2') })
    } else {
      this.InlineText(block.text, this.compact ? 'sm' : 'base', 'foreground')
    }
  }

  @Builder InlineText(value: string, textSize: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl', color: 'foreground' | 'mutedForeground') {
    Text() {
      ForEach(this.inlineSegments(value), (segment: InlineSegment) => {
        Span(segment.text)
          .fontWeight(fontWeight(segment.bold ? 'bold' : 'normal'))
      })
    }
      .width('100%')
      .fontSize(fontSize(textSize))
      .fontColor(textColor(this.scheme, color))
      .textAlign(TextAlign.Start)
      .lineHeight(this.resolveLineHeight(textSize))
  }

  @Builder TableBlock(table: MarkdownTable) {
    Scroll() {
      Column({ space: 0 }) {
        this.TableRow(table.headers, true)
        ForEach(table.rows, (row: string[], rowIndex: number) => {
          this.TableRow(row, false, rowIndex)
        })
      }
      .alignItems(HorizontalAlign.Start)
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
      .borderRadius(RADIUS.md)
      .clip(true)
    }
    .width('100%')
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Auto)
  }

  @Builder TableRow(cells: string[], header: boolean, rowIndex: number = 0) {
    Row() {
      ForEach(cells, (cell: string, cellIndex: number) => {
        Column() {
          MulticaText({
            value: cell,
            scheme: this.scheme,
            textSize: this.compact ? 'sm' : 'base',
            color: 'foreground',
            weight: header ? 'semibold' : 'normal'
          })
            .width('100%')
        }
        .constraintSize({ minWidth: this.compact ? 112 : 128 })
        .padding({ left: space('3'), right: space('3'), top: space('2.5'), bottom: space('2.5') })
        .backgroundColor(String(this.tableCellBackground(header, rowIndex)))
        .border({
          width: { right: cellIndex < cells.length - 1 ? 1 : 0, bottom: 1 },
          color: String(themeTokens(this.scheme).border)
        })
        .alignItems(HorizontalAlign.Start)
      })
    }
    .alignItems(VerticalAlign.Top)
  }

  private codeHeaderBackground(): ResourceColor {
    const t = themeTokens(this.scheme);
    return this.scheme === 'dark' ? '#202024' : '#F3F4F6';
  }

  private codeBodyBackground(): ResourceColor {
    const t = themeTokens(this.scheme);
    return this.scheme === 'dark' ? '#141417' : '#FBFBFC';
  }

  private tableCellBackground(header: boolean, rowIndex: number): ResourceColor {
    const t = themeTokens(this.scheme);
    if (header) return t.card;
    return rowIndex % 2 === 0 ? t.background : t.card;
  }

  private headingSize(level: number): 'sm' | 'base' | 'md' | 'lg' | 'xl' {
    if (level <= 1) return this.compact ? 'md' : 'xl';
    if (level === 2) return this.compact ? 'md' : 'lg';
    if (level === 3) return 'md';
    return this.compact ? 'sm' : 'base';
  }

  private resolveLineHeight(value: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl'): number {
    switch (value) {
      case 'xs':
        return 16;
      case 'sm':
        return 20;
      case 'base':
        return 24;
      case 'md':
        return 22;
      case 'lg':
        return 26;
      case 'xl':
        return 30;
      case '2xl':
        return 34;
      case '3xl':
        return 40;
      default:
        return 24;
    }
  }

  private inlineSegments(text: string): InlineSegment[] {
    const source = text ?? '';
    if (!source.length) return [{ text: '', bold: false }];
    const segments: InlineSegment[] = [];
    const regex = /@[^\s，。！？；：、】【（）()<>]+/g;
    let lastIndex = 0;
    let match = regex.exec(source);
    while (match !== null) {
      const start = match.index;
      const value = match[0];
      if (start > lastIndex) {
        segments.push({ text: source.slice(lastIndex, start), bold: false });
      }
      segments.push({ text: value, bold: true });
      lastIndex = start + value.length;
      match = regex.exec(source);
    }
    if (lastIndex < source.length) {
      segments.push({ text: source.slice(lastIndex), bold: false });
    }
    return segments;
  }

  private normalizeInline(text: string): string {
    return text
      .replace(/!\[([^\]]*)\]\(([^)]+)\)/g, '📷 $1')
      .replace(/\[([^\]]+)\]\(([^)]+)\)/g, '$1')
      .replace(/<(https?:\/\/[^>]+)>/g, '$1')
      .replace(/`([^`]+)`/g, '$1')
      .replace(/\*\*([^*]+)\*\*/g, '$1')
      .replace(/__([^_]+)__/g, '$1')
      .replace(/\*([^*]+)\*/g, '$1')
      .replace(/_([^_]+)_/g, '$1')
      .replace(/~~([^~]+)~~/g, '$1');
  }

  private cleanInline(text: string): string {
    return this.normalizeInline(stripMarkdownForDisplay(text)).trim();
  }

  private isThematicBreak(line: string): boolean {
    const normalized = line.trim().replace(/\s+/g, '');
    if (normalized.length < 3) return false;
    if (/^-{3,}$/.test(normalized)) return true;
    if (/^\*{3,}$/.test(normalized)) return true;
    if (/^_{3,}$/.test(normalized)) return true;
    return false;
  }

  private isTableSeparator(line: string): boolean {
    const trimmed = line.trim();
    if (!trimmed.includes('|')) return false;
    const normalized = trimmed.replace(/\|/g, '').replace(/:/g, '').replace(/-/g, '').trim();
    return normalized.length === 0 && /-/.test(trimmed);
  }

  private parseTableRow(line: string): string[] {
    const normalized = line.trim().replace(/^\|/, '').replace(/\|$/, '');
    if (!normalized.length) return [];
    const parts = normalized.split('|');
    const out: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      out.push(this.cleanInline(parts[i]));
    }
    return out;
  }

  private blocks(): MarkdownBlock[] {
    const raw = this.value ?? '';
    if (!raw.trim()) return [];
    const lines = raw.replace(/\r\n/g, '\n').split('\n');
    const out: MarkdownBlock[] = [];
    let inCode = false;
    let codeBuffer = '';
    let codeLanguage = '';
    let paragraphBuffer = '';

    const flushParagraph = (): void => {
      const text = this.cleanInline(paragraphBuffer);
      if (text.length > 0) {
        out.push({ kind: 'paragraph', text });
      }
      paragraphBuffer = '';
    };

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const trimmed = line.trim();

      if (trimmed.startsWith('```')) {
        flushParagraph();
        if (inCode) {
          out.push({ kind: 'code', text: codeBuffer.replace(/^\n+|\n+$/g, ''), language: codeLanguage });
          codeBuffer = '';
          codeLanguage = '';
          inCode = false;
        } else {
          inCode = true;
          codeBuffer = '';
          codeLanguage = trimmed.slice(3).trim();
        }
        continue;
      }

      if (inCode) {
        codeBuffer += (codeBuffer ? '\n' : '') + line;
        continue;
      }

      if (!trimmed) {
        flushParagraph();
        continue;
      }

      if (this.isThematicBreak(trimmed)) {
        flushParagraph();
        out.push({ kind: 'divider', text: '' });
        continue;
      }

      const nextLine = i + 1 < lines.length ? lines[i + 1].trim() : '';
      if (trimmed.includes('|') && this.isTableSeparator(nextLine)) {
        flushParagraph();
        const headers = this.parseTableRow(trimmed);
        const rows: string[][] = [];
        i += 2;
        while (i < lines.length) {
          const tableLine = lines[i].trim();
          if (!tableLine || !tableLine.includes('|')) {
            i -= 1;
            break;
          }
          rows.push(this.parseTableRow(tableLine));
          i += 1;
        }
        if (headers.length > 0) {
          out.push({ kind: 'table', text: '', table: { headers, rows } });
        }
        continue;
      }

      const headingMatch = trimmed.match(/^(#{1,6})\s+(.*)$/);
      if (headingMatch) {
        flushParagraph();
        out.push({
          kind: 'heading',
          text: this.cleanInline(headingMatch[2]),
          level: headingMatch[1].length
        });
        continue;
      }

      if (trimmed.startsWith('>')) {
        flushParagraph();
        out.push({ kind: 'quote', text: this.cleanInline(trimmed.replace(/^>\s?/, '')) });
        continue;
      }

      const taskMatch = trimmed.match(/^[-*+]\s+\[([ xX])\]\s+(.*)$/);
      if (taskMatch) {
        flushParagraph();
        out.push({
          kind: 'task',
          text: this.cleanInline(taskMatch[2]),
          checked: taskMatch[1].toLowerCase() === 'x'
        });
        continue;
      }

      const orderedMatch = trimmed.match(/^(\d+)\.\s+(.*)$/);
      if (orderedMatch) {
        flushParagraph();
        out.push({
          kind: 'bullet',
          text: this.cleanInline(orderedMatch[2]),
          ordered: true,
          marker: `${orderedMatch[1]}.`
        });
        continue;
      }

      const bulletMatch = trimmed.match(/^[-*+]\s+(.*)$/);
      if (bulletMatch) {
        flushParagraph();
        out.push({
          kind: 'bullet',
          text: this.cleanInline(bulletMatch[1]),
          ordered: false
        });
        continue;
      }

      paragraphBuffer += (paragraphBuffer ? '\n' : '') + line;
    }

    flushParagraph();

    if (inCode && codeBuffer.trim()) {
      out.push({ kind: 'code', text: codeBuffer.trim(), language: codeLanguage });
    }

    return out;
  }
}
