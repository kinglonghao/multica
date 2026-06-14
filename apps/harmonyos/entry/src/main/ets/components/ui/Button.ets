import { ColorScheme, RADIUS, space, themeTokens } from '../../lib/theme';
import { MulticaText } from './Text';

@ComponentV2
export struct MulticaButton {
  @Param label: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param variant: 'primary' | 'secondary' | 'outline' | 'destructive' | 'ghost' = 'primary';
  @Param buttonSize: 'sm' | 'md' | 'lg' = 'md';
  @Param disabled: boolean = false;
  @Param fullWidth: boolean = false;
  @Event onTap: () => void = (): void => {};

  build() {
    Row() {
      MulticaText({
        value: this.label,
        scheme: this.scheme,
        textSize: this.buttonSize === 'sm' ? 'sm' : this.buttonSize === 'lg' ? 'lg' : 'base',
        weight: 'medium',
        color: this.variant === 'primary' || this.variant === 'destructive' ? 'brandForeground' :
               this.variant === 'outline' || this.variant === 'ghost' ? 'foreground' : 'foreground'
      })
    }
    .padding({
      left: this.buttonSize === 'sm' ? space('3') : space('4'),
      right: this.buttonSize === 'sm' ? space('3') : space('4'),
      top: this.buttonSize === 'sm' ? space('2') : this.buttonSize === 'lg' ? space('3') : space('2.5'),
      bottom: this.buttonSize === 'sm' ? space('2') : this.buttonSize === 'lg' ? space('3') : space('2.5')
    })
    .backgroundColor(this.backgroundForVariant())
    .borderRadius(RADIUS.md)
    .border(this.variant === 'outline' ? { width: 1, color: String(themeTokens(this.scheme).border) } : { width: 0, color: 'transparent' })
    .opacity(this.disabled ? 0.5 : 1)
    .width(this.fullWidth ? '100%' : 'auto')
    .constraintSize({ minHeight: this.buttonSize === 'sm' ? 32 : this.buttonSize === 'lg' ? 48 : 40 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (!this.disabled) this.onTap();
    })
  }

  private backgroundForVariant(): string {
    const t = themeTokens(this.scheme);
    switch (this.variant) {
      case 'primary': return String(t.brand);
      case 'destructive': return String(t.destructive);
      case 'outline':
      case 'ghost': return 'transparent';
      case 'secondary':
      default: return String(t.card);
    }
  }
}
