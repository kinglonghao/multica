import { workspaceStore } from '../data/workspace';
import { api } from '../data/api';
import { useQuery, QueryHandle, FetchContext, queryClient } from '../queries/cache';
import { Agent } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct AgentsPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  // H-1 fix: @Local mirrors. See InboxPage.ets.
  @Local _isLoading: boolean = true;
  @Local _data: Agent[] | undefined = undefined;
  @Local _error: Error | null = null;
  private query: QueryHandle<Agent[]> | null = null;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const wsId = workspaceStore.currentId;
    this.query = useQuery<Agent[]>(
      ['agents', wsId],
      (ctx: FetchContext) => api.listAgents({ cancelToken: ctx.cancelToken }),
      { staleTimeMs: 60_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
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
    this._data = s.data as Agent[] | undefined;
    this._error = s.error;
  }

  build() {
    Column() {
      if (this._isLoading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Row() {
              Skeleton({ scheme: this.scheme, skeletonWidth: 36, skeletonHeight: 36, radius: 18 })
              Column() {
                Skeleton({ scheme: this.scheme, skeletonWidth: '50%', skeletonHeight: 12, radius: 4 })
                Skeleton({ scheme: this.scheme, skeletonWidth: '78%', skeletonHeight: 10, radius: 4 })
                  .margin({ top: space('1') })
              }
              .layoutWeight(1)
              .margin({ left: space('2.5') })
              .alignItems(HorizontalAlign.Start)
            }
            .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
          })
        }
        .layoutWeight(1)
      } else if (this._error) {
        MulticaText({
          value: `Failed to load agents: ${this._error.message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        List({ space: 0 }) {
          ForEach(this._data ?? [], (agent: Agent) => {
            ListItem() {
              Row() {
                Avatar({ name: agent.name, url: agent.avatar_url ?? '', avatarSize: 36, scheme: this.scheme })
                Column() {
                  MulticaText({
                    value: agent.name,
                    scheme: this.scheme,
                    textSize: 'sm',
                    weight: 'medium',
                    color: 'foreground'
                  })
                  if (agent.description) {
                    MulticaText({
                      value: agent.description,
                      scheme: this.scheme,
                      textSize: 'xs',
                      color: 'mutedForeground',
                      maxLines: 1,
                      overflow: 'ellipsis'
                    })
                      .margin({ top: 2 })
                  }
                }
                .layoutWeight(1)
                .margin({ left: space('2.5') })
                .alignItems(HorizontalAlign.Start)

                MulticaText({
                  value: agent.status,
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'mutedForeground'
                })
              }
              .width('100%')
              .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
              .border({
                width: { bottom: 1 },
                color: String(themeTokens(this.scheme).border)
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
