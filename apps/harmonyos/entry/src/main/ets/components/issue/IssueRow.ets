import { Issue } from '../../models/types';
import { ColorScheme, SPACE, THEME, space } from '../../lib/theme';
import { timeAgo } from '../../lib/utils';
import { MulticaText } from '../ui/Text';
import { StatusIcon } from '../ui/StatusIcon';
import { PriorityIcon } from '../ui/PriorityIcon';

@ComponentV2
export struct IssueRow {
  @Param issue: Issue = { id: '', number: 0, identifier: '', title: '', status: 'todo', priority: 'no_priority', workspace_id: '', created_at: '', updated_at: '' };
  @Param scheme: ColorScheme = 'light';
  @Event onPress: () => void = (): void => {};

  build() {
    Row() {
      Column() {
        StatusIcon({ status: this.issue.status, scheme: this.scheme, iconSize: 14 })
        PriorityIcon({ priority: this.issue.priority, scheme: this.scheme, iconSize: 14 })
          .margin({ top: space('1.5') })
      }
      .alignItems(HorizontalAlign.Center)
      .width(20)
      .margin({ right: space('2') })

      Column() {
        Row() {
          MulticaText({
            value: this.issue.identifier,
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground',
            weight: 'medium'
          })
          Blank()
          MulticaText({
            value: timeAgo(this.issue.updated_at),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')

        MulticaText({
          value: this.issue.title,
          scheme: this.scheme,
          textSize: 'base',
          weight: 'medium',
          color: 'foreground',
          maxLines: 2,
          overflow: 'ellipsis'
        })
          .margin({ top: space('1') })
          .width('100%')

        if (this.issue.assignee_name) {
          MulticaText({
            value: `Assigned to ${this.issue.assignee_name}`,
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
            .margin({ top: space('1') })
        }
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
