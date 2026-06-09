import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { useQuery, QueryHandle } from '../queries/cache';
import { ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct ChatPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  private query: QueryHandle<ChatSession[]> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const wsId = workspaceStore.currentId;
    this.query = useQuery<ChatSession[]>(
      ['chat-sessions', wsId],
      ({ signal }) => api.listChatSessions({ signal }),
      { staleTimeMs: 30_000, onUpdate: () => { this.version++; } }
    );
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({ title: 'Chat', scheme: this.scheme })

      if (!this.query) {
        return;
      }
      const state = this.query.getState();
      if (state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Row() {
              Skeleton({ scheme: this.scheme, width: 40, height: 40, radius: 20 })
              Column() {
                Skeleton({ scheme: this.scheme, width: '60%', height: 14, radius: 4 })
                Skeleton({ scheme: this.scheme, width: '85%', height: 12, radius: 4 })
                  .margin({ top: SPACE['1.5'] })
              }
              .layoutWeight(1)
              .margin({ left: SPACE['3'] })
              .alignItems(HorizontalAlign.Start)
            }
            .padding(SPACE['4'])
          })
        }
      } else {
        const sessions = state.data ?? [];
        if (sessions.length === 0) {
          Stack({ alignContent: Alignment.Center }) {
            MulticaText({
              value: 'No chat sessions yet',
              scheme: this.scheme,
              size: 'sm',
              color: 'mutedForeground',
              textAlign: TextAlign.Center
            })
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          List({ space: 0 }) {
            ForEach(sessions, (session) => {
              ListItem() {
                Row() {
                  Avatar({
                    name: session.agent_name ?? '·',
                    url: session.agent_avatar_url ?? '',
                    size: 40,
                    scheme: this.scheme
                  })
                  Column() {
                    Row() {
                      MulticaText({
                        value: session.agent_name ?? 'Agent',
                        scheme: this.scheme,
                        size: 'base',
                        weight: 'medium',
                        color: 'foreground'
                      })
                      Blank()
                      MulticaText({
                        value: timeAgo(session.last_message_at ?? session.updated_at),
                        scheme: this.scheme,
                        size: 'xs',
                        color: 'mutedForeground'
                      })
                    }
                    .width('100%')
                    MulticaText({
                      value: session.last_message_preview ?? '',
                      scheme: this.scheme,
                      size: 'sm',
                      color: 'mutedForeground',
                      maxLines: 1,
                      overflow: 'ellipsis'
                    })
                      .margin({ top: SPACE['1'] })
                  }
                  .layoutWeight(1)
                  .margin({ left: SPACE['3'] })
                  .alignItems(HorizontalAlign.Start)
                }
                .padding(SPACE['4'])
                .onClick(() => {
                  // H-1: chat sessions open the chat detail page,
                  // not the issue detail page.
                  appNavigation.pushName('ChatDetailPage', { id: session.id });
                })
              }
              .divider({ strokeWidth: 1, color: String(THEME[this.scheme].border) })
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
