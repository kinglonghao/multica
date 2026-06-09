import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle } from '../queries/cache';
import { ChatMessage, ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct ChatDetailPage {
  @Local id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local inputDraft: string = '';
  @Local sending: boolean = false;
  private session: QueryHandle<ChatSession> | null = null;
  private messages: QueryHandle<ChatMessage[]> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.id = appNavigation.readString('ChatDetailPage', 'id', '');
    this.session = useQuery<ChatSession>(
      ['chat-session', this.id],
      ({ signal }) => api.getChatSession(this.id, { signal }),
      { staleTimeMs: 30_000, onUpdate: () => { this.version++; } }
    );
    this.messages = useQuery<ChatMessage[]>(
      ['chat-messages', this.id],
      ({ signal }) => api.listChatMessages(this.id, { signal }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; } }
    );
  }

  aboutToDisappear(): void {
    this.session?.unsubscribe();
    this.messages?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async send(): Promise<void> {
    const text = this.inputDraft.trim();
    if (!text || this.sending) return;
    this.sending = true;
    try {
      await api.sendChatMessage(this.id, text);
      this.inputDraft = '';
      this.messages?.refetch();
    } catch (err) {
      console.warn('[chat] send failed', err);
    } finally {
      this.sending = false;
    }
  }

  build() {
    Column() {
      Header({
        title: this.session?.getState().data?.title ?? 'Chat',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (!this.messages) {
        return;
      }
      const mState = this.messages.getState();
      const sState = this.session?.getState();
      const session = sState?.data;
      Scroll() {
        Column() {
          if (mState.isLoading) {
            ForEach([1, 2, 3], () => {
              Skeleton({ scheme: this.scheme, width: '90%', height: 40, radius: 8 })
                .margin({ top: SPACE['2'], left: SPACE['4'], right: SPACE['4'] })
            })
          } else if (mState.data) {
            ForEach(mState.data, (msg: ChatMessage) => {
              this.MessageRow(msg, session)
            })
          }
        }
        .width('100%')
        .padding({ top: SPACE['2'], bottom: SPACE['2'] })
      }
      .layoutWeight(1)
      .width('100%')

      Row() {
        TextInput({ placeholder: 'Message…', text: this.inputDraft })
          .placeholderColor(String(THEME[this.scheme].mutedForeground))
          .fontColor(String(THEME[this.scheme].foreground))
          .backgroundColor(String(THEME[this.scheme].card))
          .borderRadius(RADIUS.full)
          .padding(SPACE['3'])
          .layoutWeight(1)
          .onChange((value: string) => { this.inputDraft = value; })
        MulticaText({
          value: this.sending ? '…' : '↑',
          scheme: this.scheme,
          size: 'xl',
          weight: 'bold',
          color: 'brand'
        })
          .margin({ left: SPACE['3'] })
          .onClick(() => { void this.send(); })
      }
      .width('100%')
      .padding(SPACE['3'])
      .border({
        width: { top: 1 },
        color: String(THEME[this.scheme].border)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder MessageRow(msg: ChatMessage, session: ChatSession | undefined) {
    Row() {
      if (msg.role === 'assistant') {
        Avatar({ name: session?.agent_name ?? '·', url: session?.agent_avatar_url ?? '', size: 28, scheme: this.scheme })
      } else {
        Blank().width(28)
      }
      Column() {
        MulticaText({
          value: msg.content,
          scheme: this.scheme,
          size: 'sm',
          color: 'foreground'
        })
        MulticaText({
          value: timeAgo(msg.created_at),
          scheme: this.scheme,
          size: 'xs',
          color: 'mutedForeground'
        })
          .margin({ top: SPACE['0.5'] })
      }
      .layoutWeight(1)
      .margin({ left: SPACE['2'] })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['1'], bottom: SPACE['1'] })
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
