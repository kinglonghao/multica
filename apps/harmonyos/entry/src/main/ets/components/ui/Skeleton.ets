import { THEME, ColorScheme, RADIUS } from '../../lib/theme';

@Component
export struct Skeleton {
  @Prop scheme: ColorScheme = 'light';
  @Prop width: string | number = '100%';
  @Prop height: number = 16;
  @Prop radius: number = RADIUS.DEFAULT;

  build() {
    Stack()
      .width(this.width)
      .height(this.height)
      .backgroundColor(String(THEME[this.scheme].border))
      .borderRadius(this.radius)
      .opacity(0.6)
  }
}
