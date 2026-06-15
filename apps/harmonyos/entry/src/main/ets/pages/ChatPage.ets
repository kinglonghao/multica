import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE, space, themeTokens } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct ChatPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  // H-1 fix: @Local mirrors of the cache state. See InboxPage.ets.
  @Local _isLoading: boolean = true;
  @Local _data: ChatSession[] | undefined = undefined;
  @Local _error: Error | null = null;
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
    return 'light';
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

  build() {
    Column() {
      Header({ title: 'Chat', scheme: this.scheme })

      if (this._isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Row() {
              Skeleton({ scheme: this.scheme, skeletonWidth: 40, skeletonHeight: 40, radius: 20 })
              Column() {
                Skeleton({ scheme: this.scheme, skeletonWidth: '60%', skeletonHeight: 14, radius: 4 })
                Skeleton({ scheme: this.scheme, skeletonWidth: '85%', skeletonHeight: 12, radius: 4 })
                  .margin({ top: space('1.5') })
              }
              .layoutWeight(1)
              .margin({ left: space('3') })
              .alignItems(HorizontalAlign.Start)
            }
            .padding(space('4'))
          })
        }
      } else if (this._error) {
        MulticaText({
          value: `Failed to load chats: ${this._error.message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else if (this.chatSessions().length === 0) {
        Stack({ alignContent: Alignment.Center }) {
          MulticaText({
            value: 'No chat sessions yet',
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground',
            textAlign: 'center'
          })
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        List({ space: 0 }) {
          ForEach(this.chatSessions(), (session: ChatSession) => {
            ListItem() {
              Row() {
                Avatar({
                  name: session.agent_name ?? '·',
                  url: session.agent_avatar_url ?? '',
                  avatarSize: 40,
                  scheme: this.scheme
                })
                Column() {
                  Row() {
                    MulticaText({
                      value: session.agent_name ?? 'Agent',
                      scheme: this.scheme,
                      textSize: 'base',
                      weight: 'medium',
                      color: 'foreground'
                    })
                    Blank()
                    MulticaText({
                      value: timeAgo(session.last_message_at ?? session.updated_at),
                      scheme: this.scheme,
                      textSize: 'xs',
                      color: 'mutedForeground'
                    })
                  }
                  .width('100%')
                  MulticaText({
                    value: session.last_message_preview ?? '',
                    scheme: this.scheme,
                    textSize: 'sm',
                    color: 'mutedForeground',
                    maxLines: 1,
                    overflow: 'ellipsis'
                  })
                    .margin({ top: space('1') })
                }
                .layoutWeight(1)
                .margin({ left: space('3') })
                .alignItems(HorizontalAlign.Start)
              }
              .padding(space('4'))
                .border({
                  width: { bottom: 1 },
                  color: String(themeTokens(this.scheme).border)
                })
              .onClick(() => {
                // H-1: chat sessions open the chat detail page,
                // not the issue detail page.
                appNavigation.pushName('ChatDetailPage', navParam('id', session.id));
              })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
