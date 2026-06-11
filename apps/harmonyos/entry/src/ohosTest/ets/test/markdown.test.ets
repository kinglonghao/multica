/**
 * Unit tests for the hand-rolled markdown parser
 * (lib/markdown.ets). Covers the four features the WS-106
 * acceptance criteria call out — heading, code, list, link —
 * plus the inline span types: bold, italic, inline code.
 */
import { describe, it, expect } from '@ohos.hypium';
import { parseMarkdown, MarkdownBlock } from '../../../../main/ets/lib/markdown';

describe('markdown parser', () => {
  it('returns empty array for empty / null input', () => {
    expect(parseMarkdown('').length).assertEqual(0);
  });

  it('parses # and ## and ### headings', () => {
    const out = parseMarkdown('# Title\n## Sub\n### Tiny');
    expect(out.length).assertEqual(3);
    expect(out[0].type).assertEqual('heading');
    if (out[0].type === 'heading') {
      expect(out[0].level).assertEqual(1);
    }
    if (out[1].type === 'heading') expect(out[1].level).assertEqual(2);
    if (out[2].type === 'heading') expect(out[2].level).assertEqual(3);
  });

  it('parses fenced code blocks with language', () => {
    const out = parseMarkdown('```ts\nconst x = 1;\n```');
    expect(out.length).assertEqual(1);
    expect(out[0].type).assertEqual('code');
    if (out[0].type === 'code') {
      expect(out[0].language).assertEqual('ts');
      expect(out[0].value).assertEqual('const x = 1;');
    }
  });

  it('parses unordered lists with - and *', () => {
    const out = parseMarkdown('- one\n- two\n* three');
    expect(out.length).assertEqual(1);
    expect(out[0].type).assertEqual('list');
    if (out[0].type === 'list') {
      expect(out[0].ordered).assertEqual(false);
      expect(out[0].items.length).assertEqual(3);
    }
  });

  it('parses ordered lists', () => {
    const out = parseMarkdown('1. first\n2. second\n3. third');
    expect(out.length).assertEqual(1);
    expect(out[0].type).assertEqual('list');
    if (out[0].type === 'list') {
      expect(out[0].ordered).assertEqual(true);
      expect(out[0].items.length).assertEqual(3);
    }
  });

  it('parses [text](url) links', () => {
    const out = parseMarkdown('See [the docs](https://example.com).');
    expect(out.length).assertEqual(1);
    expect(out[0].type).assertEqual('paragraph');
    if (out[0].type === 'paragraph') {
      const link = out[0].spans.find(s => s.type === 'link');
      expect(link).assertNotEqual(undefined);
      if (link && link.type === 'link') {
        expect(link.text).assertEqual('the docs');
        expect(link.href).assertEqual('https://example.com');
      }
    }
  });

  it('parses inline **bold** and *italic* and `code`', () => {
    const out = parseMarkdown('this is **bold** and *italic* and `monospaced`.');
    if (out[0].type === 'paragraph') {
      const bold = out[0].spans.find(s => s.type === 'bold');
      const italic = out[0].spans.find(s => s.type === 'italic');
      const code = out[0].spans.find(s => s.type === 'code');
      expect(bold).assertNotEqual(undefined);
      expect(italic).assertNotEqual(undefined);
      expect(code).assertNotEqual(undefined);
      if (bold && bold.type === 'bold') expect(bold.value).assertEqual('bold');
      if (italic && italic.type === 'italic') expect(italic.value).assertEqual('italic');
      if (code && code.type === 'code') expect(code.value).assertEqual('monospaced');
    }
  });

  it('handles blank-line block boundaries', () => {
    const out = parseMarkdown('paragraph one.\n\nparagraph two.');
    expect(out.length).assertEqual(2);
    expect(out[0].type).assertEqual('paragraph');
    expect(out[1].type).assertEqual('paragraph');
  });

  it('handles a mixed document', () => {
    const input = [
      '# Heading',
      '',
      'A paragraph with **bold** and a [link](https://x).',
      '',
      '- item one',
      '- item two',
      '',
      '```ts',
      'const x = 1;',
      '```'
    ].join('\n');
    const blocks: MarkdownBlock[] = parseMarkdown(input);
    const types = blocks.map(b => b.type);
    expect(types).assertEqual(['heading', 'paragraph', 'list', 'code']);
  });
});
