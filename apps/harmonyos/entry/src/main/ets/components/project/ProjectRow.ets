import { Project } from '../../models/types';
import { ColorScheme, SPACE, RADIUS } from '../../lib/theme';
import { projectStatusLabel, projectPriorityLabel } from '../../lib/project-status';
import { MulticaText } from '../ui/Text';
import { ProjectStatusIcon, ProjectPriorityIcon } from '../ui/ProjectStatusIcon';

@Component
export struct ProjectRow {
  @Prop project: Project = { id: '', name: '', identifier: '', status: 'planned', priority: 'no_priority', workspace_id: '', created_at: '', updated_at: '' };
  @Prop scheme: ColorScheme = 'light';
  onPress: () => void = () => {};

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        MulticaText({
          value: this.project.identifier,
          scheme: this.scheme,
          size: 'xs',
          weight: 'bold',
          color: 'brandForeground'
        })
      }
      .width(36)
      .height(36)
      .borderRadius(RADIUS.md)
      .backgroundColor('#5046E4')
      .margin({ right: SPACE['3'] })

      Column() {
        MulticaText({
          value: this.project.name,
          scheme: this.scheme,
          size: 'base',
          weight: 'medium',
          color: 'foreground',
          maxLines: 1,
          overflow: 'ellipsis'
        })
        Row() {
          ProjectStatusIcon({ status: this.project.status, scheme: this.scheme, size: 12 })
          MulticaText({
            value: projectStatusLabel(this.project.status),
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
            .margin({ left: SPACE['1'] })
          ProjectPriorityIcon({ priority: this.project.priority, scheme: this.scheme, size: 12 })
            .margin({ left: SPACE['2'] })
          MulticaText({
            value: projectPriorityLabel(this.project.priority),
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
            .margin({ left: SPACE['1'] })
        }
        .margin({ top: SPACE['1'] })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: SPACE['4'],
      right: SPACE['4'],
      top: SPACE['3'],
      bottom: SPACE['3']
    })
    .onClick(() => { this.onPress(); })
  }
}
