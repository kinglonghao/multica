import { THEME, ColorScheme, RADIUS } from '../../lib/theme';
import { MulticaText } from '../ui/Text';

/**
 * Square-rounded initial chip for workspaces. Distinct from
 * `Avatar` (which is a circle for users/agents) — workspaces
 * use a 4px rounded square to make the hierarchy obvious in
 * a multi-entity list.
 */
@ComponentV2
export struct WorkspaceAvatar {
  @Param name: string = '';
  @Param slug: string = '';
  @Param scheme: ColorScheme = 'light';
  @Param size: number = 28;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.initial(),
        scheme: this.scheme,
        size: this.size > 40 ? 'lg' : this.size > 28 ? 'base' : 'sm',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width(this.size)
    .height(this.size)
    .borderRadius(RADIUS.sm)
    .backgroundColor(this.color())
  }

  private initial(): string {
    const source = (this.name || this.slug).trim();
    if (!source) return '·';
    return source.substring(0, 1).toUpperCase();
  }

  /**
   * Stable color per workspace. Picks from a small palette based
   * on a hash of the slug so the same workspace always lands on
   * the same color across sessions.
   */
  private color(): string {
    const palette: string[] = [
      '#5046E4', // brand indigo
      '#9333EA', // agent purple
      '#16A34A', // success green
      '#2563EB', // info blue
      '#D97706', // warning amber
      '#DC2626'  // destructive red
    ];
    let h = 0;
    for (let i = 0; i < this.slug.length; i++) {
      h = (h * 31 + this.slug.charCodeAt(i)) >>> 0;
    }
    return palette[h % palette.length];
  }
}
