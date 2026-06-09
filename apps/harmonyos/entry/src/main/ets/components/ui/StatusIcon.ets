import { IssueStatus } from '../../models/types';
import { ColorScheme } from '../../lib/theme';
import { statusColor, statusLabel } from '../../lib/issue-status';
import { MulticaText } from './Text';

/**
 * Status icon — colored circle with a one-letter glyph. Mirrors
 * apps/mobile/components/ui/status-icon.tsx. Letter is derived from
 * the status key (B/T/I/R/D/C) so the icon is self-describing even
 * at small sizes.
 */
@Component
export struct StatusIcon {
  @Prop status: IssueStatus | string = 'backlog';
  @Prop scheme: ColorScheme = 'light';
  @Prop size: number = 16;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph(this.status),
        scheme: this.scheme,
        size: 'xs',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width(this.size)
    .height(this.size)
    .borderRadius(this.size / 2)
    .backgroundColor(statusColor(this.status, this.scheme))
  }

  private glyph(status: string): string {
    switch (status) {
      case 'backlog': return 'B';
      case 'todo': return 'T';
      case 'in_progress': return 'I';
      case 'in_review': return 'R';
      case 'done': return 'D';
      case 'cancelled': return 'C';
      default: return '·';
    }
  }
}
