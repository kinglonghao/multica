import { Project } from '../../models/types';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../../lib/theme';
import { projectStatusLabel, projectPriorityLabel } from '../../lib/project-status';
import { MulticaText } from '../ui/Text';
import { ProjectStatusIcon, ProjectPriorityIcon } from '../ui/ProjectStatusIcon';

@ComponentV2
export struct ProjectRow {
  @Param project: Project = { id: '', name: '', identifier: '', status: 'planned', priority: 'no_priority', workspace_id: '', created_at: '', updated_at: '' };
  @Param scheme: ColorScheme = 'light';
  @Event onPress: () => void = (): void => {};

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        MulticaText({
          value: '📁',
          scheme: this.scheme,
          textSize: 'lg',
          weight: 'medium'
        })
      }
      .width(40)
      .height(40)
      .borderRadius(12)
      .backgroundColor(String(themeTokens(this.scheme).card))
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
      .margin({ right: space('3') })

      Column() {
        MulticaText({
          value: this.project.name,
          scheme: this.scheme,
          textSize: 'base',
          weight: 'medium',
          color: 'foreground',
          maxLines: 1,
          overflow: 'ellipsis'
        })
        Row() {
          ProjectStatusIcon({ status: this.project.status, scheme: this.scheme, iconSize: 12 })
          MulticaText({
            value: projectStatusLabel(this.project.status),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
            .margin({ left: space('1') })
          ProjectPriorityIcon({ priority: this.project.priority, scheme: this.scheme, iconSize: 12 })
            .margin({ left: space('2') })
          MulticaText({
            value: projectPriorityLabel(this.project.priority),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
            .margin({ left: space('1') })
        }
        .margin({ top: space('1') })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: space('4'),
      right: space('4'),
      top: space('3'),
      bottom: space('3')
    })
    .onClick(() => { this.onPress(); })
  }
}
