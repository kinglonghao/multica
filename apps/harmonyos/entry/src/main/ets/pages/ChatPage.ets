import router from '@ohos.router';
import { api } from '../data/api';
import { useQuery } from '../queries/cache';
import { ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@Component
export struct ChatPage {
  @State scheme: ColorScheme = 'light';
  private query = useQuery<ChatSession[]>(
    ['chat-sessions'],
    ({ signal }) => api.listChatSessions({ signal }),
    { staleTimeMs: 30_000 }
  );

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({ title: 'Chat', scheme: this.scheme })

      if (this.query.state.isLoading) {
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
        const sessions = this.query.state.data ?? [];
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
                  router.pushUrl({ url: 'pages/IssueDetailPage', params: { id: session.id } });
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
