import { appNavigation } from '../data/navigation';
import { workspaceStore } from '../data/workspace';
import { Workspace } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';

@ComponentV2
export struct SelectWorkspacePage {
  @Local scheme: ColorScheme = 'light';
  @Local workspaces: Workspace[] = [];
  @Local loading: boolean = true;
  @Local error: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    void this.load();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async load(): Promise<void> {
    try {
      this.workspaces = await workspaceStore.fetchWorkspaces();
    } catch (err) {
      this.error = err instanceof Error ? err.message : 'Failed to load workspaces';
    } finally {
      this.loading = false;
    }
  }

  private async pick(ws: Workspace): Promise<void> {
    await workspaceStore.setCurrent(ws.id, ws.slug);
    // Bug 3 fix: clear the destination stack to expose the root
    // WorkspaceLayout, which re-renders against the newly-selected
    // workspace.
    appNavigation.clear();
  }

  build() {
    Column() {
      Header({ title: 'Select workspace', scheme: this.scheme })

      if (this.loading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 56, radius: 8 })
              .margin({ top: space('3') })
          })
        }
        .padding(space('4'))
        .width('100%')
      } else if (this.error) {
        MulticaText({
          value: this.error,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        List({ space: 0 }) {
          ForEach(this.workspaces, (ws: Workspace) => {
            ListItem() {
              Row() {
                MulticaText({
                  value: ws.name,
                  scheme: this.scheme,
                  textSize: 'base',
                  weight: 'medium',
                  color: 'foreground'
                })
              }
              .width('100%')
              .padding(space('4'))
              .backgroundColor(String(themeTokens(this.scheme).card))
              .borderRadius(RADIUS.md)
              .margin({ top: space('2'), left: space('4'), right: space('4') })
              .onClick(() => { void this.pick(ws); })
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
