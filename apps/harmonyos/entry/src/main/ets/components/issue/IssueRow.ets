import { Issue } from '../../models/types';
import { ColorScheme, SPACE, THEME } from '../../lib/theme';
import { timeAgo } from '../../lib/utils';
import { MulticaText } from '../ui/Text';
import { StatusIcon } from '../ui/StatusIcon';
import { PriorityIcon } from '../ui/PriorityIcon';

@Component
export struct IssueRow {
  @Prop issue: Issue = { id: '', number: 0, identifier: '', title: '', status: 'todo', priority: 'no_priority', workspace_id: '', created_at: '', updated_at: '' };
  @Prop scheme: ColorScheme = 'light';
  onPress: () => void = () => {};

  build() {
    Row() {
      Column() {
        StatusIcon({ status: this.issue.status, scheme: this.scheme, size: 14 })
        PriorityIcon({ priority: this.issue.priority, scheme: this.scheme, size: 14 })
          .margin({ top: SPACE['1.5'] })
      }
      .alignItems(HorizontalAlign.Center)
      .width(20)
      .margin({ right: SPACE['2'] })

      Column() {
        Row() {
          MulticaText({
            value: this.issue.identifier,
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground',
            weight: 'medium'
          })
          Blank()
          MulticaText({
            value: timeAgo(this.issue.updated_at),
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')

        MulticaText({
          value: this.issue.title,
          scheme: this.scheme,
          size: 'base',
          weight: 'medium',
          color: 'foreground',
          maxLines: 2,
          overflow: 'ellipsis'
        })
          .margin({ top: SPACE['1'] })
          .width('100%')

        if (this.issue.assignee_name) {
          MulticaText({
            value: `Assigned to ${this.issue.assignee_name}`,
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['1'] })
        }
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
