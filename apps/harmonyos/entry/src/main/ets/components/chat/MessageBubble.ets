import { THEME, ColorScheme, RADIUS, SPACE } from '../../lib/theme';
import { MulticaText } from '../ui/Text';
import { ChatMessage } from '../../models/types';
import { timeAgo } from '../../lib/utils';

/**
 * Single chat message bubble. Different from the inline
 * `MessageRow` builder in `ChatDetailPage` so we can re-use it
 * from `NewChatPage` previews and any future pinned message /
 * search-result context. Colors follow the chat convention:
 * user messages align right with the brand surface; assistant
 * messages align left with the card surface.
 */
@ComponentV2
export struct MessageBubble {
  @Param message: ChatMessage = { id: '', role: 'user', content: '', created_at: '' };
  @Param scheme: ColorScheme = 'light';
  @Param agentName: string = '';

  build() {
    Row() {
      if (this.message.role === 'assistant') {
        this.Bubble()
        Blank().layoutWeight(1)
      } else {
        Blank().layoutWeight(1)
        this.Bubble()
      }
    }
    .width('100%')
    .padding({ left: SPACE['3'], right: SPACE['3'], top: SPACE['1'], bottom: SPACE['1'] })
  }

  @Builder Bubble() {
    Column() {
      MulticaText({
        value: this.message.content,
        scheme: this.scheme,
        size: 'sm',
        color: this.message.role === 'assistant' ? 'foreground' : 'brandForeground'
      })
      MulticaText({
        value: timeAgo(this.message.created_at),
        scheme: this.scheme,
        size: 'xs',
        color: this.message.role === 'assistant' ? 'mutedForeground' : 'brandForeground'
      })
        .margin({ top: SPACE['1'] })
    }
    .constraintSize({ maxWidth: '78%' })
    .alignItems(HorizontalAlign.Start)
    .padding(SPACE['3'])
    .borderRadius(RADIUS.lg)
    .backgroundColor(this.bubbleColor())
  }

  private bubbleColor(): string {
    const t = THEME[this.scheme];
    if (this.message.role === 'assistant') {
      return String(t.card);
    }
    return String(t.brand);
  }
}
