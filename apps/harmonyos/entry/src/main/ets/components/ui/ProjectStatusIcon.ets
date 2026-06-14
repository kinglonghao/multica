import { ProjectStatus, ProjectPriority } from '../../models/types';
import { ColorScheme } from '../../lib/theme';
import { projectStatusColor, projectPriorityColor } from '../../lib/project-status';
import { MulticaText } from './Text';

@ComponentV2
export struct ProjectStatusIcon {
  @Param status: ProjectStatus | string = 'planned';
  @Param scheme: ColorScheme = 'light';
  @Param iconSize: number = 16;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph(this.status),
        scheme: this.scheme,
        textSize: 'xs',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.iconSize / 2)
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

@ComponentV2
export struct ProjectPriorityIcon {
  @Param priority: ProjectPriority | string = 'no_priority';
  @Param scheme: ColorScheme = 'light';
  @Param iconSize: number = 16;

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MulticaText({
        value: this.glyph(this.priority),
        scheme: this.scheme,
        textSize: 'xs',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width(this.iconSize)
    .height(this.iconSize)
    .borderRadius(this.iconSize / 2)
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
