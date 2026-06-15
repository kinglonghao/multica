import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { useChatRealtime } from '../realtime/realtime-hooks';
import { ChatMessage, ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct ChatDetailPage {
  @Param chatId: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local inputDraft: string = '';
  @Local sending: boolean = false;
  @Local sendError: string = '';
  // H-1 fix: @Local mirrors. See InboxPage.ets.
  @Local _session: ChatSession | undefined = undefined;
  @Local _sessionIsLoading: boolean = true;
  @Local _sessionError: Error | null = null;
  @Local _messages: ChatMessage[] | undefined = undefined;
  @Local _messagesIsLoading: boolean = true;
  @Local _messagesError: Error | null = null;
  private session: QueryHandle<ChatSession> | null = null;
  private messages: QueryHandle<ChatMessage[]> | null = null;
  private wsUnsub?: () => void;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.session = useQuery<ChatSession>(
      ['chat-session', this.chatId],
      (ctx: FetchContext) => api.getChatSession(this.chatId, { cancelToken: ctx.cancelToken }),
      { staleTimeMs: 30_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.messages = useQuery<ChatMessage[]>(
      ['chat-messages', this.chatId],
      (ctx: FetchContext) => api.listChatMessages(this.chatId, { cancelToken: ctx.cancelToken }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    // Subscribe to chat:message events for this session. The
    // hook patches the cache in place — incoming assistant
    // messages stream in without a refetch.
    this.wsUnsub = useChatRealtime(this.chatId);
  }

  aboutToDisappear(): void {
    this.session?.unsubscribe();
    this.messages?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private syncFromCache(): void {
    if (this.session) {
      const s = this.session.getState();
      this._session = s.data as ChatSession | undefined;
      this._sessionIsLoading = s.isLoading;
      this._sessionError = s.error;
    }
    if (this.messages) {
      const s = this.messages.getState();
      this._messages = s.data as ChatMessage[] | undefined;
      this._messagesIsLoading = s.isLoading;
      this._messagesError = s.error;
    }
  }

  private async send(): Promise<void> {
    const text = this.inputDraft.trim();
    if (!text || this.sending) return;
    this.sending = true;
    this.sendError = '';
    try {
      await api.sendChatMessage(this.chatId, text);
      this.inputDraft = '';
      // Refetch on send so the user's message + the agent's
      // eventual response both land; the WS hook handles the
      // interim assistant message.
      this.messages?.refetch();
    } catch (err) {
      this.sendError = err instanceof Error ? err.message : 'Failed to send message';
    } finally {
      this.sending = false;
    }
  }

  build() {
    Column() {
      Header({
        title: this._session?.title ?? 'Chat',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (this._messagesIsLoading) {
        Scroll() {
          Column() {
            ForEach([1, 2, 3], () => {
              Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 40, radius: 8 })
                .margin({ top: space('2'), left: space('4'), right: space('4') })
            })
          }
          .width('100%')
          .padding({ top: space('2'), bottom: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this._messagesError) {
        MulticaText({
          value: `Failed to load messages: ${this._messagesError.message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        Scroll() {
          Column() {
            ForEach(this._messages ?? [], (msg: ChatMessage) => {
              this.MessageRow(msg, this._session)
            })
          }
          .width('100%')
          .padding({ top: space('2'), bottom: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
      }

      if (this.sendError) {
        MulticaText({
          value: this.sendError,
          scheme: this.scheme,
          textSize: 'xs',
          color: 'destructive'
        })
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('1') })
      }

      Row() {
        TextInput({ placeholder: 'Message…', text: this.inputDraft })
          .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
          .fontColor(String(themeTokens(this.scheme).foreground))
          .backgroundColor(String(themeTokens(this.scheme).card))
          .borderRadius(RADIUS.full)
          .padding(space('3'))
          .layoutWeight(1)
          .onChange((value: string) => { this.inputDraft = value; })
        MulticaText({
          value: this.sending ? '…' : '↑',
          scheme: this.scheme,
          textSize: 'xl',
          weight: 'bold',
          color: 'brand'
        })
          .margin({ left: space('3') })
          .onClick(() => { void this.send(); })
      }
      .width('100%')
      .padding(space('3'))
      .border({
        width: { top: 1 },
        color: String(themeTokens(this.scheme).border)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder MessageRow(msg: ChatMessage, session: ChatSession | undefined) {
    Row() {
      if (msg.role === 'assistant') {
        Avatar({ name: session?.agent_name ?? '·', url: session?.agent_avatar_url ?? '', avatarSize: 28, scheme: this.scheme })
      } else {
        Blank().width(28)
      }
      Column() {
        MulticaText({
          value: msg.content,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'foreground'
        })
        MulticaText({
          value: timeAgo(msg.created_at),
          scheme: this.scheme,
          textSize: 'xs',
          color: 'mutedForeground'
        })
          .margin({ top: space('0.5') })
      }
      .layoutWeight(1)
      .margin({ left: space('2') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('1'), bottom: space('1') })
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
