import { appNavigation } from '../data/navigation';
import { workspaceStore } from '../data/workspace';
import { Workspace } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct SwitchWorkspacePage {
  @Local scheme: ColorScheme = 'light';
  @Local workspaces: Workspace[] = [];
  @Local loading: boolean = true;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    void this.load();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private async load(): Promise<void> {
    try {
      this.workspaces = await workspaceStore.fetchWorkspaces();
    } catch (err) {
      console.warn('[switch-workspace] load failed', err);
    } finally {
      this.loading = false;
    }
  }

  private async pick(ws: Workspace): Promise<void> {
    await workspaceStore.setCurrent(ws.id, ws.slug);
    appNavigation.clear();
  }

  build() {
    Column() {
      if (this.loading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 48, radius: RADIUS.lg })
              .margin({ top: space('2') })
          })
        }
        .layoutWeight(1)
        .padding({ left: space('3'), right: space('3'), top: space('3') })
        .width('100%')
      } else {
        List({ space: 0 }) {
          ForEach(this.workspaces, (ws: Workspace) => {
            ListItem() {
              Row() {
                Column() {
                  MulticaText({
                    value: ws.name,
                    scheme: this.scheme,
                    textSize: 'sm',
                    weight: 'medium',
                    color: 'foreground'
                  })
                  if (ws.slug) {
                    MulticaText({
                      value: ws.slug,
                      scheme: this.scheme,
                      textSize: 'xs',
                      color: 'mutedForeground'
                    })
                      .margin({ top: 2 })
                  }
                }
                .alignItems(HorizontalAlign.Start)

                Blank()

                if (ws.id === workspaceStore.currentId) {
                  MulticaText({
                    value: '✓',
                    scheme: this.scheme,
                    textSize: 'sm',
                    weight: 'semibold',
                    color: 'brand'
                  })
                }
              }
              .width('100%')
              .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
              .onClick(() => { void this.pick(ws); })
            }
          })
        }
        .layoutWeight(1)
        .width('100%')
        .padding({ left: space('3'), right: space('3'), top: space('3') })
        .divider(null)
        .backgroundColor(String(themeTokens(this.scheme).background))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
