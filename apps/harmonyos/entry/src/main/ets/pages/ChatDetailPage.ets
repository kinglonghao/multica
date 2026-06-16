import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { authStore } from '../data/auth';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { useChatRealtime } from '../realtime/realtime-hooks';
import { ChatMessage, ChatSession } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
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

  private currentUserName(): string {
    const user = authStore.getState().user;
    return user?.display_name ?? user?.email ?? 'Me';
  }

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
    this.wsUnsub = useChatRealtime(this.chatId);
  }

  aboutToDisappear(): void {
    this.session?.unsubscribe();
    this.messages?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
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

  private sessionTitle(): string {
    const agentName = this._session?.agent_name?.trim() ?? '';
    if (agentName) return agentName;
    const title = this._session?.title?.trim() ?? '';
    if (title) return title;
    return 'Chat';
  }

  private sessionSubtitle(): string {
    const title = this._session?.title?.trim() ?? '';
    if (title) return title;
    return 'New chat';
  }

  private async send(): Promise<void> {
    const text = this.inputDraft.trim();
    if (!text || this.sending) return;
    this.sending = true;
    this.sendError = '';
    try {
      await api.sendChatMessage(this.chatId, text);
      this.inputDraft = '';
      this.messages?.refetch();
    } catch (err) {
      this.sendError = err instanceof Error ? err.message : 'Failed to send message';
    } finally {
      this.sending = false;
    }
  }

  build() {
    Column() {
      this.PageHeader()

      if (this._messagesIsLoading) {
        Scroll() {
          Column() {
            ForEach([1, 2, 3], () => {
              this.MessageSkeleton()
            })
          }
          .width('100%')
          .padding({ top: space('2'), bottom: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this._messagesError) {
        Column() {
          MulticaText({
            value: `Failed to load messages: ${this._messagesError.message}`,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'destructive'
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding(space('4'))
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            ForEach(this._messages ?? [], (msg: ChatMessage) => {
              this.MessageRow(msg)
            })
          }
          .width('100%')
          .padding({ left: space('1'), right: space('1'), top: space('2'), bottom: space('3') })
          .alignItems(HorizontalAlign.Start)
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

      this.Composer()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder PageHeader() {
    Row() {
      Row() {
        MulticaText({
          value: '‹',
          scheme: this.scheme,
          textSize: 'lg',
          weight: 'medium',
          color: 'foreground'
        })
      }
      .width(36)
      .height(36)
      .borderRadius(RADIUS.full)
      .backgroundColor('#F4F4F5')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .onClick(() => { appNavigation.pop(); })

      Column() {
        MulticaText({
          value: this.sessionTitle(),
          scheme: this.scheme,
          textSize: 'base',
          weight: 'semibold',
          color: 'foreground',
          maxLines: 1,
          overflow: 'ellipsis'
        })
        MulticaText({
          value: this.sessionSubtitle(),
          scheme: this.scheme,
          textSize: 'xs',
          color: 'mutedForeground',
          maxLines: 1,
          overflow: 'ellipsis'
        })
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .margin({ left: space('3') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('2'), bottom: space('2') })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .alignItems(VerticalAlign.Center)
  }

  @Builder MessageSkeleton() {
    Row() {
      Skeleton({ scheme: this.scheme, skeletonWidth: 28, skeletonHeight: 28, radius: 14 })
      Column() {
        Skeleton({ scheme: this.scheme, skeletonWidth: '70%', skeletonHeight: 16, radius: 8 })
        Skeleton({ scheme: this.scheme, skeletonWidth: '92%', skeletonHeight: 48, radius: 16 })
          .margin({ top: space('2') })
      }
      .layoutWeight(1)
      .margin({ left: space('2') })
    }
    .width('100%')
    .padding({ left: space('3'), right: space('3'), top: space('2'), bottom: space('2') })
    .alignItems(VerticalAlign.Top)
  }

  @Builder Composer() {
    Column() {
      Row() {
        TextInput({ placeholder: 'Message…', text: this.inputDraft })
          .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
          .fontColor(String(themeTokens(this.scheme).foreground))
          .backgroundColor(String(themeTokens(this.scheme).card))
          .borderRadius(RADIUS.full)
          .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
          .layoutWeight(1)
          .onChange((value: string) => { this.inputDraft = value; })

        Row() {
          MulticaText({
            value: this.sending ? '…' : '↑',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'bold',
            color: 'brandForeground'
          })
        }
        .width(40)
        .height(40)
        .margin({ left: space('2') })
        .borderRadius(RADIUS.full)
        .backgroundColor(String(themeTokens(this.scheme).brand))
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .opacity(this.inputDraft.trim() || this.sending ? 1 : 0.55)
        .onClick(() => { void this.send(); })
      }
      .width('100%')
      .padding({ left: space('3'), right: space('3'), top: space('2'), bottom: space('2') })
      .backgroundColor(String(themeTokens(this.scheme).background))
    }
    .width('100%')
    .padding({ left: space('2'), right: space('2'), top: space('1'), bottom: space('2') })
    .border({
      width: { top: 1 },
      color: String(themeTokens(this.scheme).border)
    })
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder MessageRow(msg: ChatMessage) {
    Row() {
      if (msg.role === 'assistant') {
        Avatar({
          name: this.sessionTitle(),
          url: this._session?.agent_avatar_url ?? '',
          avatarSize: 30,
          scheme: this.scheme
        })
      } else {
        Blank().layoutWeight(1)
      }

      Column() {
        if (msg.role === 'assistant') {
          MulticaText({
            value: this.sessionTitle(),
            scheme: this.scheme,
            textSize: 'xs',
            weight: 'semibold',
            color: 'foreground'
          })
            .margin({ bottom: 2 })
        }
        Column() {
          MulticaText({
            value: msg.content,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'foreground'
          })
        }
        .padding({ left: space('3'), right: space('3'), top: space('2.5'), bottom: space('2.5') })
        .backgroundColor(msg.role === 'assistant' ? '#F6F7FB' : '#EFEFFD')
        .borderRadius(20)
        .border({ width: 1, color: msg.role === 'assistant' ? '#ECECF1' : '#DCDCFB' })

        MulticaText({
          value: timeAgo(msg.created_at),
          scheme: this.scheme,
          textSize: 'xs',
          color: 'mutedForeground',
          textAlign: msg.role === 'assistant' ? 'start' : 'end'
        })
          .margin({ top: space('1') })
      }
      .constraintSize({ maxWidth: '82%' })
      .margin({ left: msg.role === 'assistant' ? space('2') : 0 })
      .alignItems(msg.role === 'assistant' ? HorizontalAlign.Start : HorizontalAlign.End)
    }
    .width('100%')
    .padding({ left: space('3'), right: space('3'), top: space('1.5'), bottom: space('1.5') })
    .alignItems(VerticalAlign.Top)
  }
}
