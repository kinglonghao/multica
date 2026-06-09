import { textColor, ColorScheme, FONT_SIZE, FONT_WEIGHT, TextColorKey } from '../../lib/theme';

@ComponentV2
export struct MulticaText {
  @Param value: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param size: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl' = 'base';
  @Param weight: 'normal' | 'medium' | 'semibold' | 'bold' = 'normal';
  @Param color: TextColorKey = 'foreground';
  @Param textAlign: 'start' | 'center' | 'end' = 'start';
  @Param maxLines: number = 0;
  @Param overflow: 'clip' | 'ellipsis' | 'visible' = 'clip';

  build() {
    Text(this.value)
      .fontSize(FONT_SIZE[this.size])
      .fontWeight(FONT_WEIGHT[this.weight])
      .fontColor(textColor(this.scheme, this.color))
      .textAlign(this.textAlign)
      .maxLines(this.maxLines > 0 ? this.maxLines : 1000000)
      .textOverflow(this.overflow === 'ellipsis' ? { overflow: TextOverflow.Ellipsis } : { overflow: TextOverflow.Clip })
  }
}
