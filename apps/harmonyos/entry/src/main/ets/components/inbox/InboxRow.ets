import { InboxItem } from '../../models/types';
import { ColorScheme, space, themeTokens } from '../../lib/theme';
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
      if (!this.item.read) {
        Stack()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(String(themeTokens(this.scheme).brand))
          .margin({ top: 6, right: space('2') })
      } else {
        Blank().width(6).margin({ right: space('2') })
      }

      Stack({ alignContent: Alignment.Center }) {
        if (this.item.actor_avatar_url) {
          Image(this.item.actor_avatar_url)
            .width(36)
            .height(36)
            .borderRadius(18)
            .objectFit(ImageFit.Cover)
        } else {
          Avatar({ name: this.item.actor_name ?? '·', avatarSize: 36, scheme: this.scheme })
        }
      }
      .width(36)
      .height(36)

      Column() {
        Row() {
          MulticaText({
            value: this.summary(),
            scheme: this.scheme,
            textSize: 'sm',
            weight: this.item.read ? 'normal' : 'medium',
            color: this.item.read ? 'mutedForeground' : 'foreground',
            maxLines: 1,
            overflow: 'ellipsis'
          })
            .layoutWeight(1)
          MulticaText({
            value: timeAgo(this.item.created_at),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        if (this.issueTitle) {
          Row() {
            this.IssueBadge()
            MulticaText({
              value: `${this.issueIdentifier} · ${this.issueTitle}`,
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground',
              maxLines: 1,
              overflow: 'ellipsis'
            })
              .layoutWeight(1)
              .margin({ left: space('2') })
          }
          .width('100%')
          .margin({ top: space('1') })
          .alignItems(VerticalAlign.Center)
        }
      }
      .layoutWeight(1)
      .margin({ left: space('3') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: space('4'),
      right: space('4'),
      top: space('3'),
      bottom: space('3')
    })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .border({
      width: { bottom: 1 },
      color: String(themeTokens(this.scheme).border)
    })
    .onClick(() => { this.onPress(); })
  }

  @Builder IssueBadge() {
    Stack({ alignContent: Alignment.Center }) {
      Row()
        .width(16)
        .height(16)
        .borderRadius(8)
        .backgroundColor(String(themeTokens(this.scheme).card))
      StatusIcon({ status: 'todo', scheme: this.scheme, iconSize: 10 })
    }
    .width(16)
    .height(16)
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
