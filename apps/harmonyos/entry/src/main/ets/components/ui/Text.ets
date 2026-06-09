import { THEME, ColorScheme, FONT_SIZE, FONT_WEIGHT } from '../../lib/theme';

@Component
export struct MulticaText {
  @Prop value: string = '';
  @Prop scheme: ColorScheme = 'light';
  @Prop size: 'xs' | 'sm' | 'base' | 'md' | 'lg' | 'xl' | '2xl' | '3xl' = 'base';
  @Prop weight: 'normal' | 'medium' | 'semibold' | 'bold' = 'normal';
  @Prop color: 'foreground' | 'mutedForeground' | 'destructive' | 'brand' | 'success' | 'warning' = 'foreground';
  @Prop textAlign: 'start' | 'center' | 'end' = 'start';
  @Prop maxLines: number = 0;
  @Prop overflow: 'clip' | 'ellipsis' | 'visible' = 'clip';

  build() {
    Text(this.value)
      .fontSize(FONT_SIZE[this.size])
      .fontWeight(FONT_WEIGHT[this.weight])
      .fontColor(String(THEME[this.scheme][this.color]))
      .textAlign(this.textAlign)
      .maxLines(this.maxLines > 0 ? this.maxLines : 1000000)
      .textOverflow(this.overflow === 'ellipsis' ? { overflow: TextOverflow.Ellipsis } : { overflow: TextOverflow.Clip })
  }
}
