import { IssuePriority } from '../../models/types';
import { ColorScheme } from '../../lib/theme';
import { priorityColor } from '../../lib/issue-status';
import { MulticaText } from './Text';

@ComponentV2
export struct PriorityIcon {
  @Param priority: IssuePriority | string = 'no_priority';
  @Param scheme: ColorScheme = 'light';
  @Param size: number = 16;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph(this.priority),
        scheme: this.scheme,
        size: 'xs',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width(this.size)
    .height(this.size)
    .borderRadius(this.size / 2)
    .backgroundColor(priorityColor(this.priority, this.scheme))
  }

  private glyph(priority: string): string {
    switch (priority) {
      case 'urgent': return '!';
      case 'high': return '↑';
      case 'medium': return '=';
      case 'low': return '↓';
      case 'no_priority':
      default: return '–';
    }
  }
}
