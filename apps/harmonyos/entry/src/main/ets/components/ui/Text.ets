import { textColor, ColorScheme, FONT_SIZE, FONT_WEIGHT, TextColorKey, fontSize, fontWeight } from '../../lib/theme';

function resolveTextAlign(value: 'start' | 'center' | 'end'): TextAlign {
  switch (value) {
    case 'center':
      return TextAlign.Center;
    case 'end':
      return TextAlign.End;
    case 'start':
    default:
      return TextAlign.Start;
  }
}

function resolveLineHeight(value: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl'): number {
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

@ComponentV2
export struct MulticaText {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param textSize: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl' = 'base';
  @Param weight: 'normal' | 'medium' | 'semibold' | 'bold' = 'normal';
  @Param color: TextColorKey = 'foreground';
  @Param textAlign: 'start' | 'center' | 'end' = 'start';
  @Param maxLines: number = 0;
  @Param overflow: 'clip' | 'ellipsis' | 'visible' = 'clip';

  build() {
    Text(this.value)
      .fontSize(fontSize(this.textSize))
      .fontWeight(fontWeight(this.weight))
      .fontColor(textColor(this.scheme, this.color))
      .textAlign(resolveTextAlign(this.textAlign))
      .lineHeight(resolveLineHeight(this.textSize))
      .maxLines(this.maxLines > 0 ? this.maxLines : 1000000)
      .textOverflow(this.overflow === 'ellipsis' ? { overflow: TextOverflow.Ellipsis } : { overflow: TextOverflow.Clip })
  }
}
