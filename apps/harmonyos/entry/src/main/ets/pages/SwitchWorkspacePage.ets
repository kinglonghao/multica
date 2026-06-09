import { appNavigation } from '../data/navigation';
import { workspaceStore } from '../data/workspace';
import { Workspace } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
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
    return 'light';
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
    appNavigation.replaceName('WorkspaceLayout');
  }

  build() {
    Column() {
      Header({
        title: 'Switch workspace',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (this.loading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Skeleton({ scheme: this.scheme, width: '90%', height: 56, radius: 8 })
              .margin({ top: SPACE['3'] })
          })
        }
        .padding(SPACE['4'])
        .width('100%')
      } else {
        List({ space: 0 }) {
          ForEach(this.workspaces, (ws: Workspace) => {
            ListItem() {
              Row() {
                MulticaText({
                  value: ws.name,
                  scheme: this.scheme,
                  size: 'base',
                  weight: 'medium',
                  color: 'foreground'
                })
                if (ws.id === workspaceStore.currentId) {
                  Blank()
                  MulticaText({
                    value: '✓',
                    scheme: this.scheme,
                    size: 'base',
                    weight: 'medium',
                    color: 'brand'
                  })
                }
              }
              .width('100%')
              .padding(SPACE['4'])
              .backgroundColor(String(THEME[this.scheme].card))
              .borderRadius(RADIUS.md)
              .margin({ top: SPACE['2'], left: SPACE['4'], right: SPACE['4'] })
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
    .backgroundColor(String(THEME[this.scheme].background))
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
