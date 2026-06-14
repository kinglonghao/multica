import { THEME, ColorScheme, RADIUS, themeTokens } from '../../lib/theme';

@ComponentV2
export struct Skeleton {
  @Param scheme: ColorScheme = 'light';
  @Param skeletonWidth: Length = '100%';
  @Param skeletonHeight: Length = 16;
  @Param radius: number = RADIUS.DEFAULT;

  build() {
    Stack()
      .width(this.skeletonWidth)
      .height(this.skeletonHeight)
      .backgroundColor(String(themeTokens(this.scheme).border))
      .borderRadius(this.radius)
      .opacity(0.6)
  }
}
