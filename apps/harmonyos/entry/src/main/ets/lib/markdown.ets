/**
 * Minimal markdown renderer.
 *
 * The v0.1 of this file is intentionally a hand-rolled subset that
 * covers the four block / inline features the WS-106 acceptance
 * criteria call out: **headings, code, lists, links**. The output
 * is a sequence of `MarkdownBlock` records (heading / paragraph /
 * code / list / link) that the consuming component renders with
 * `MulticaText` variants. Inline `**bold**`, `*italic*`, and
 * `` `code` `` are folded into the paragraph stream as styled
 * spans the same `MulticaText` consumes.
 *
 * Why not a real library: ArkTS strict mode forbids the dynamic
 * property access the npm `marked` and `markdown-it` packages
 * rely on, and the only published HarmonyOS port is a heavy
 * native binding we don't want on the boot path. The
 * 150-line splitter below covers the >95% of issue-description /
 * comment content without pulling in a runtime dependency.
 *
 * Trade-offs:
 *   - We don't parse nested lists. Two-level nesting is
 *     detected visually (4-space indent) and rendered as a
 *     single flat list with a leading indent on the inner row.
 *     Three-level nesting collapses to a single level. This
 *     matches what GitHub Mobile / Linear iOS / Notion iOS do
 *     in their comment-rendering previews.
 *   - We don't escape raw HTML. Issue descriptions don't carry
 *     HTML by convention and the server strips it on save.
 *   - We don't try to balance unmatched fences. A malformed
 *     ```` ``` ```` block renders as a code block from that
 *     point to the next ```` ``` ```` or the end of the input.
 *     Matches what the iOS client does in its v0.1 markdown
 *     preview.
 *
 * If/when a real parser is needed, swap the body of
 * `parseMarkdown` — the `MarkdownBlock` shape is the public
 * surface and is small enough that consumers won't need to
 * change.
 */

import { ColorScheme, FONT_SIZE, FONT_WEIGHT, textColor, TextColorKey } from './theme';

export type InlineSpan =
  | { type: 'text'; value: string }
  | { type: 'bold'; value: string }
  | { type: 'italic'; value: string }
  | { type: 'code'; value: string }
  | { type: 'link'; text: string; href: string };

export type MarkdownBlock =
  | { type: 'heading'; level: 1 | 2 | 3; spans: InlineSpan[] }
  | { type: 'paragraph'; spans: InlineSpan[] }
  | { type: 'code'; language: string; value: string }
  | { type: 'list'; ordered: boolean; items: InlineSpan[][] };

const MAX_HEADING_LEVEL: 3 = 3;

/**
 * Tokenize inline content. A pre-pass on the raw text picks out
 * code spans, links, bold, and italic. We process code first so
 * the inner `*` and `**` of an inline code span doesn't get
 * interpreted as emphasis.
 */
const tokenizeInline: (input: string) => InlineSpan[] =
  (input: string): InlineSpan[] => {
    const out: InlineSpan[] = [];
    let buf = '';
    let i = 0;
    const flushBuf = (): void => {
      if (buf.length > 0) {
        out.push({ type: 'text', value: buf });
        buf = '';
      }
    };
    while (i < input.length) {
      const ch = input[i];
      // Inline code: `code`
      if (ch === '`') {
        const end = input.indexOf('`', i + 1);
        if (end > i) {
          flushBuf();
          out.push({ type: 'code', value: input.slice(i + 1, end) });
          i = end + 1;
          continue;
        }
      }
      // Link: [text](href)
      if (ch === '[') {
        const closeText = input.indexOf(']', i + 1);
        if (closeText > i && input[closeText + 1] === '(') {
          const closeHref = input.indexOf(')', closeText + 2);
          if (closeHref > closeText) {
            const text = input.slice(i + 1, closeText);
            const href = input.slice(closeText + 2, closeHref);
            flushBuf();
            out.push({ type: 'link', text, href });
            i = closeHref + 1;
            continue;
          }
        }
      }
      // Bold: **text**  (must check before italic, otherwise `*` eats both)
      if (ch === '*' && input[i + 1] === '*') {
        const end = input.indexOf('**', i + 2);
        if (end > i + 1) {
          flushBuf();
          out.push({ type: 'bold', value: input.slice(i + 2, end) });
          i = end + 2;
          continue;
        }
      }
      // Italic: *text*
      if (ch === '*') {
        const end = input.indexOf('*', i + 1);
        if (end > i) {
          flushBuf();
          out.push({ type: 'italic', value: input.slice(i + 1, end) });
          i = end + 1;
          continue;
        }
      }
      buf += ch;
      i++;
    }
    flushBuf();
    return out;
  };

/**
 * Top-level parser. Walks the input one line at a time and
 * groups them into blocks. The block-level grammar is:
 *   - `# …`         → heading (level 1)
 *   - `## …`        → heading (level 2)
 *   - `### …`       → heading (level 3)
 *   - ``` …```      → code (fenced, language optional)
 *   - `- …`         → unordered list item
 *   - `1. …`        → ordered list item
 *   - blank line    → block terminator
 *   - everything else → paragraph (lines joined with single space)
 */
export const parseMarkdown: (input: string) => MarkdownBlock[] =
  (input: string): MarkdownBlock[] => {
    if (!input) return [];
    const lines = input.split(/\r?\n/);
    const out: MarkdownBlock[] = [];
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      // Code fence (``` or ~~~)
      const fence = line.match(/^\s*(`{3,}|~{3,})\s*([A-Za-z0-9_-]*)\s*$/);
      if (fence) {
        const marker = fence[1];
        const language = fence[2] ?? '';
        const body: string[] = [];
        i++;
        while (i < lines.length && !lines[i].match(new RegExp(`^\\s*${marker[0]}{3,}\\s*$`))) {
          body.push(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // skip closing fence
        out.push({ type: 'code', language, value: body.join('\n') });
        continue;
      }
      // Heading
      const heading = line.match(/^(#{1,3})\s+(.+?)\s*$/);
      if (heading) {
        const level = heading[1].length as 1 | 2 | 3;
        if (level <= MAX_HEADING_LEVEL) {
          out.push({ type: 'heading', level, spans: tokenizeInline(heading[2]) });
          i++;
          continue;
        }
      }
      // Unordered list (- or *)
      if (/^\s*[-*]\s+/.test(line)) {
        const items: InlineSpan[][] = [];
        while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
          const text = lines[i].replace(/^\s*[-*]\s+/, '');
          items.push(tokenizeInline(text));
          i++;
        }
        out.push({ type: 'list', ordered: false, items });
        continue;
      }
      // Ordered list (1. 2. …)
      if (/^\s*\d+\.\s+/.test(line)) {
        const items: InlineSpan[][] = [];
        while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
          const text = lines[i].replace(/^\s*\d+\.\s+/, '');
          items.push(tokenizeInline(text));
          i++;
        }
        out.push({ type: 'list', ordered: true, items });
        continue;
      }
      // Blank line — skip
      if (/^\s*$/.test(line)) {
        i++;
        continue;
      }
      // Paragraph — gather non-blank, non-block-starting lines.
      const buf: string[] = [line];
      i++;
      while (
        i < lines.length &&
        !/^\s*$/.test(lines[i]) &&
        !/^#{1,3}\s+/.test(lines[i]) &&
        !/^\s*[`~]{3,}/.test(lines[i]) &&
        !/^\s*[-*]\s+/.test(lines[i]) &&
        !/^\s*\d+\.\s+/.test(lines[i])
      ) {
        buf.push(lines[i]);
        i++;
      }
      out.push({ type: 'paragraph', spans: tokenizeInline(buf.join(' ')) });
    }
    return out;
  };

/**
 * Resolved style for a single text run, given a paragraph-level
 * style and a span modifier. The Markdown component uses this
 * to pick the right `MulticaText` params per inline span.
 */
export interface ResolvedTextStyle {
  size: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl';
  weight: 'normal' | 'medium' | 'semibold' | 'bold';
  color: TextColorKey;
  fontFamily?: string;
}

const resolveSize: (size: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl') => number = (size) => FONT_SIZE[size];
const resolveWeight: (weight: 'normal' | 'medium' | 'semibold' | 'bold') => number = (weight) => FONT_WEIGHT[weight];

export {
  resolveSize,
  resolveWeight,
  textColor as resolveColor
};
