import { Issue } from '../../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../../lib/theme';
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
        Row() {
          StatusIcon({ status: this.issue.status, scheme: this.scheme, iconSize: 12 })
        }
        .width(26)
        .height(26)
        .borderRadius(RADIUS.full)
        .backgroundColor(String(themeTokens(this.scheme).card))
        .border({ width: 1, color: String(themeTokens(this.scheme).border) })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        Row() {
          PriorityIcon({ priority: this.issue.priority, scheme: this.scheme, iconSize: 9 })
        }
        .width(16)
        .height(16)
        .borderRadius(RADIUS.full)
        .backgroundColor(String(themeTokens(this.scheme).background))
        .margin({ top: 4 })
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .alignItems(HorizontalAlign.Center)
      .width(26)
      .margin({ right: space('2.5') })

      Column() {
        Row() {
          Row() {
            MulticaText({
              value: this.issue.identifier,
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground',
              weight: 'semibold'
            })
          }
          .padding({ left: space('1.5'), right: space('1.5'), top: 2, bottom: 2 })
          .borderRadius(RADIUS.full)
          .backgroundColor(String(themeTokens(this.scheme).card))

          Blank()

          MulticaText({
            value: timeAgo(this.issue.updated_at),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        MulticaText({
          value: this.issue.title,
          scheme: this.scheme,
          textSize: 'sm',
          weight: 'semibold',
          color: 'foreground',
          maxLines: 2,
          overflow: 'ellipsis'
        })
          .margin({ top: space('1.5') })
          .width('100%')

        if (this.issue.assignee_name) {
          Row() {
            MulticaText({
              value: this.issue.assignee_name,
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground'
            })
          }
          .margin({ top: space('1.5') })
          .padding({ left: space('1.5'), right: space('1.5'), top: 3, bottom: 3 })
          .borderRadius(RADIUS.full)
          .backgroundColor(String(themeTokens(this.scheme).card))
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: space('3'),
      right: space('3'),
      top: space('3'),
      bottom: space('3')
    })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .borderRadius(RADIUS.lg)
    .border({ width: 1, color: String(themeTokens(this.scheme).border) })
    .onClick(() => { this.onPress(); })
  }
}
