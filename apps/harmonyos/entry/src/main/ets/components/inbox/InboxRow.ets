import { InboxItem } from '../../models/types';
import { ColorScheme, THEME, SPACE } from '../../lib/theme';
import { timeAgo } from '../../lib/utils';
import { MulticaText } from '../ui/Text';
import { Avatar } from '../ui/Avatar';
import { StatusIcon } from '../ui/StatusIcon';

@ComponentV2
export struct InboxRow {
  @Param item: InboxItem = { id: '', type: 'mention', read: false, archived: false, workspace_id: '', created_at: '', updated_at: '' };
  @Param scheme: ColorScheme = 'light';
  @Param issueIdentifier: string = '';
  @Param issueTitle: string = '';
  @Event onPress: () => void = (): void => {};

  build() {
    Row() {
      Stack({ alignContent: Alignment.Center }) {
        if (this.item.actor_avatar_url) {
          Image(this.item.actor_avatar_url)
            .width(36)
            .height(36)
            .borderRadius(18)
            .objectFit(ImageFit.Cover)
        } else {
          Avatar({ name: this.item.actor_name ?? '·', size: 36, scheme: this.scheme })
        }
      }
      .width(40)
      .height(40)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)

      Column() {
        Row() {
          MulticaText({
            value: this.summary(),
            scheme: this.scheme,
            size: 'sm',
            weight: this.item.read ? 'normal' : 'medium',
            color: 'foreground',
            maxLines: 2,
            overflow: 'ellipsis'
          })
            .layoutWeight(1)
          MulticaText({
            value: timeAgo(this.item.created_at),
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.issueTitle) {
          Row() {
            StatusIcon({ status: 'todo', scheme: this.scheme, size: 12 })
            MulticaText({
              value: `${this.issueIdentifier} · ${this.issueTitle}`,
              scheme: this.scheme,
              size: 'xs',
              color: 'mutedForeground',
              maxLines: 1,
              overflow: 'ellipsis'
            })
              .layoutWeight(1)
              .margin({ left: SPACE['1.5'] })
          }
          .width('100%')
          .margin({ top: SPACE['1'] })
          .alignItems(VerticalAlign.Center)
        }
      }
      .layoutWeight(1)
      .margin({ left: SPACE['3'] })
      .alignItems(HorizontalAlign.Start)

      if (!this.item.read) {
        Stack()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(String(THEME[this.scheme].brand))
          .margin({ left: SPACE['2'] })
      }
    }
    .width('100%')
    .padding({
      left: SPACE['4'],
      right: SPACE['4'],
      top: SPACE['3'],
      bottom: SPACE['3']
    })
    .backgroundColor(this.item.read ? 'transparent' : String(THEME[this.scheme].card))
    .onClick(() => { this.onPress(); })
  }

  private summary(): string {
    const who = this.item.actor_name ?? 'Someone';
    switch (this.item.type) {
      case 'mention': return `${who} mentioned you`;
      case 'assignment': return `${who} assigned an issue to you`;
      case 'status': return `${who} changed the status`;
      case 'comment': return `${who} commented`;
      case 'review_request': return `${who} requested your review`;
      default: return `${who} updated an issue`;
    }
  }
}
