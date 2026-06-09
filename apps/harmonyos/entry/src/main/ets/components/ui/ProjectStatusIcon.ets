import { ProjectStatus, ProjectPriority } from '../../models/types';
import { ColorScheme } from '../../lib/theme';
import { projectStatusColor, projectPriorityColor } from '../../lib/project-status';
import { MulticaText } from './Text';

@Component
export struct ProjectStatusIcon {
  @Prop status: ProjectStatus | string = 'planned';
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
    .backgroundColor(projectStatusColor(this.status, this.scheme))
  }

  private glyph(status: string): string {
    switch (status) {
      case 'planned': return 'P';
      case 'in_progress': return 'I';
      case 'paused': return '·';
      case 'completed': return '✓';
      case 'cancelled': return 'C';
      default: return '·';
    }
  }
}

@Component
export struct ProjectPriorityIcon {
  @Prop priority: ProjectPriority | string = 'no_priority';
  @Prop scheme: ColorScheme = 'light';
  @Prop size: number = 16;

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
    .backgroundColor(projectPriorityColor(this.priority, this.scheme))
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
