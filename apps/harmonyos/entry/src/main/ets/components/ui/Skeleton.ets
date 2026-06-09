import { THEME, ColorScheme, RADIUS } from '../../lib/theme';

@ComponentV2
export struct Skeleton {
  @Param scheme: ColorScheme = 'light';
  @Param width: string | number = '100%';
  @Param height: number = 16;
  @Param radius: number = RADIUS.DEFAULT;

  build() {
    Stack()
      .width(this.width)
      .height(this.height)
      .backgroundColor(String(THEME[this.scheme].border))
      .borderRadius(this.radius)
      .opacity(0.6)
  }
}
