import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { ChatSession } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';
import { IconButton } from '../components/ui/IconButton';

@ComponentV2
export struct ChatPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local _isLoading: boolean = true;
  @Local _data: ChatSession[] | undefined = undefined;
  @Local _error: Error | null = null;
  @Local pressedSessionId: string = '';
  private query: QueryHandle<ChatSession[]> | null = null;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const wsId = workspaceStore.currentId;
    this.query = useQuery<ChatSession[]>(
      ['chat-sessions', wsId],
      (ctx: FetchContext) => api.listChatSessions({ cancelToken: ctx.cancelToken }),
      { staleTimeMs: 30_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.globalUnsub?.();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private syncFromCache(): void {
    if (!this.query) return;
    const s = this.query.getState();
    this._isLoading = s.isLoading;
    this._data = s.data as ChatSession[] | undefined;
    this._error = s.error;
  }

  private chatSessions(): ChatSession[] {
    return this._data ?? [];
  }

  private sessionTitle(session: ChatSession): string {
    const agentName = session.agent_name?.trim() ?? '';
    if (agentName) return agentName;
    const title = session.title?.trim() ?? '';
    if (title) return title;
    return 'Untitled chat';
  }

  private sessionSubtitle(session: ChatSession): string {
    const title = session.title?.trim() ?? '';
    if (title) return title;
    return 'New chat';
  }

  build() {
    Column() {
      Header({
        title: 'Chat',
        scheme: this.scheme,
        right: this.ChatHeaderRight
      })

      if (this._isLoading) {
        this.LoadingState()
      } else if (this._error) {
        MulticaText({
          value: `Failed to load chats: ${this._error.message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else if (this.chatSessions().length === 0) {
        this.EmptyState()
      } else {
        List({ space: 0 }) {
          ForEach(this.chatSessions(), (session: ChatSession) => {
            ListItem() {
              this.ChatRow(session)
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder ChatHeaderRight() {
    IconButton({
      glyph: '⋯',
      scheme: this.scheme,
      accessibilityLabel: 'Chat actions',
      onTap: () => {}
    })
  }

  @Builder LoadingState() {
    Column() {
      ForEach([1, 2, 3, 4, 5, 6], () => {
        Row() {
          Skeleton({ scheme: this.scheme, skeletonWidth: 36, skeletonHeight: 36, radius: 18 })
          Column() {
            Skeleton({ scheme: this.scheme, skeletonWidth: '54%', skeletonHeight: 14, radius: 4 })
            Skeleton({ scheme: this.scheme, skeletonWidth: '72%', skeletonHeight: 12, radius: 4 })
              .margin({ top: space('1.5') })
          }
          .layoutWeight(1)
          .margin({ left: space('3') })
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
      })
    }
  }

  @Builder EmptyState() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: 'No chats yet',
          scheme: this.scheme,
          textSize: 'base',
          weight: 'medium',
          color: 'foreground',
          textAlign: 'center'
        })
        MulticaText({
          value: 'Pick an agent and start a new conversation.',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'mutedForeground',
          textAlign: 'center'
        })
          .margin({ top: space('2') })
      }
      .padding({ left: space('6'), right: space('6') })
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder ChatRow(session: ChatSession) {
    Row() {
      Avatar({
        name: this.sessionTitle(session),
        url: session.agent_avatar_url ?? '',
        avatarSize: 36,
        scheme: this.scheme
      })

      Column() {
        Row() {
          MulticaText({
            value: this.sessionTitle(session),
            scheme: this.scheme,
            textSize: 'sm',
            weight: (session.unread_count ?? 0) > 0 ? 'semibold' : 'medium',
            color: 'foreground',
            maxLines: 1,
            overflow: 'ellipsis'
          })
            .layoutWeight(1)
          MulticaText({
            value: timeAgo(session.last_message_at ?? session.updated_at),
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)

        MulticaText({
          value: this.sessionSubtitle(session),
          scheme: this.scheme,
          textSize: 'xs',
          color: 'mutedForeground',
          maxLines: 1,
          overflow: 'ellipsis'
        })
          .margin({ top: 4 })
      }
      .layoutWeight(1)
      .margin({ left: space('3') })
      .alignItems(HorizontalAlign.Start)

      if ((session.unread_count ?? 0) > 0) {
        Stack()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(String(themeTokens(this.scheme).brand))
          .margin({ left: space('2') })
      }
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
    .backgroundColor(this.pressedSessionId === session.id ? '#F4F4F5' : String(themeTokens(this.scheme).background))
    .border({
      width: { bottom: 1 },
      color: String(themeTokens(this.scheme).border)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.pressedSessionId = session.id;
        })
    )
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedSessionId = session.id;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedSessionId = '';
      }
    })
    .onClick(() => {
      this.pressedSessionId = '';
      appNavigation.pushName('ChatDetailPage', navParam('id', session.id));
    })
  }
}
