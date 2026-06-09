import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';
import { MulticaText } from './Text';

@Component
export struct MulticaButton {
  @Prop label: string = '';
  @Prop scheme: ColorScheme = 'light';
  @Prop variant: 'primary' | 'secondary' | 'outline' | 'destructive' | 'ghost' = 'primary';
  @Prop size: 'sm' | 'md' | 'lg' = 'md';
  @Prop disabled: boolean = false;
  @Prop fullWidth: boolean = false;
  onTap: () => void = () => {};

  build() {
    Row() {
      MulticaText({
        value: this.label,
        scheme: this.scheme,
        size: this.size === 'sm' ? 'sm' : this.size === 'lg' ? 'lg' : 'base',
        weight: 'medium',
        color: this.variant === 'primary' || this.variant === 'destructive' ? 'brandForeground' :
               this.variant === 'outline' || this.variant === 'ghost' ? 'foreground' : 'foreground'
      })
    }
    .padding({
      left: this.size === 'sm' ? SPACE['3'] : SPACE['4'],
      right: this.size === 'sm' ? SPACE['3'] : SPACE['4'],
      top: this.size === 'sm' ? SPACE['2'] : this.size === 'lg' ? SPACE['3'] : SPACE['2.5'],
      bottom: this.size === 'sm' ? SPACE['2'] : this.size === 'lg' ? SPACE['3'] : SPACE['2.5']
    })
    .backgroundColor(this.backgroundForVariant())
    .borderRadius(RADIUS.md)
    .border(this.variant === 'outline' ? { width: 1, color: String(THEME[this.scheme].border) } : { width: 0, color: 'transparent' })
    .opacity(this.disabled ? 0.5 : 1)
    .width(this.fullWidth ? '100%' : 'auto')
    .constraintSize({ minHeight: this.size === 'sm' ? 32 : this.size === 'lg' ? 48 : 40 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      if (!this.disabled) this.onTap();
    })
  }

  private backgroundForVariant(): string {
    const t = THEME[this.scheme];
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
