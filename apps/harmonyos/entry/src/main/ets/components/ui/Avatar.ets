import { THEME, ColorScheme, RADIUS } from '../../lib/theme';
import { MulticaText } from './Text';

@Component
export struct Avatar {
  @Prop name: string = '';
  @Prop url: string = '';
  @Prop size: number = 36;
  @Prop scheme: ColorScheme = 'light';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.url) {
        Image(this.url)
          .width(this.size)
          .height(this.size)
          .borderRadius(this.size / 2)
          .objectFit(ImageFit.Cover)
      } else {
        Stack({ alignContent: Alignment.Center }) {
          MulticaText({
            value: this.initials(this.name),
            scheme: this.scheme,
            size: this.size > 56 ? 'xl' : this.size > 40 ? 'lg' : 'base',
            weight: 'semibold',
            color: 'brandForeground'
          })
        }
        .width(this.size)
        .height(this.size)
        .borderRadius(this.size / 2)
        .backgroundColor(this.fallbackColor(this.name))
      }
    }
  }

  private initials(name: string): string {
    if (!name) return '?';
    const parts = name.trim().split(/\s+/);
    if (parts.length === 1) return parts[0].substring(0, 2).toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  private fallbackColor(name: string): string {
    // Stable color from name hash. We use a small palette of muted
    // hues that read as "neutral" — never a saturated brand color, to
    // avoid clashing with the brand/agent treatment elsewhere.
    const palette = ['#71717A', '#A1A1AA', '#52525B', '#3F3F46', '#737373', '#78716C'];
    let h = 0;
    for (let i = 0; i < name.length; i++) {
      h = (h * 31 + name.charCodeAt(i)) >>> 0;
    }
    return palette[h % palette.length];
  }
}
