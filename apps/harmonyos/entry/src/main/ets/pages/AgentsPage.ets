import { api } from '../data/api';
import { useQuery } from '../queries/cache';
import { Agent } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@Entry
@Component
struct AgentsPage {
  @State scheme: ColorScheme = 'light';
  private query = useQuery<Agent[]>(
    ['agents'],
    ({ signal }) => api.listAgents({ signal }),
    { staleTimeMs: 60_000 }
  );

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({ title: 'Agents', scheme: this.scheme })

      if (this.query.state.isLoading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Row() {
              Skeleton({ scheme: this.scheme, width: 40, height: 40, radius: 20 })
              Column() {
                Skeleton({ scheme: this.scheme, width: '50%', height: 14, radius: 4 })
                Skeleton({ scheme: this.scheme, width: '80%', height: 12, radius: 4 })
                  .margin({ top: SPACE['1.5'] })
              }
              .layoutWeight(1)
              .margin({ left: SPACE['3'] })
              .alignItems(HorizontalAlign.Start)
            }
            .padding(SPACE['4'])
          })
        }
      } else if (this.query.state.error) {
        MulticaText({
          value: `Failed to load agents: ${this.query.state.error!.message}`,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
      } else {
        List({ space: 0 }) {
          ForEach(this.query.state.data ?? [], (agent: Agent) => {
            ListItem() {
              Row() {
                Avatar({ name: agent.name, url: agent.avatar_url ?? '', size: 40, scheme: this.scheme })
                Column() {
                  MulticaText({
                    value: agent.name,
                    scheme: this.scheme,
                    size: 'base',
                    weight: 'medium',
                    color: 'foreground'
                  })
                  if (agent.description) {
                    MulticaText({
                      value: agent.description,
                      scheme: this.scheme,
                      size: 'xs',
                      color: 'mutedForeground',
                      maxLines: 1,
                      overflow: 'ellipsis'
                    })
                      .margin({ top: SPACE['0.5'] })
                  }
                }
                .layoutWeight(1)
                .margin({ left: SPACE['3'] })
                .alignItems(HorizontalAlign.Start)

                MulticaText({
                  value: agent.status,
                  scheme: this.scheme,
                  size: 'xs',
                  color: 'mutedForeground'
                })
              }
              .width('100%')
              .padding(SPACE['4'])
            }
            .divider({ strokeWidth: 1, color: String(THEME[this.scheme].border) })
          })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
