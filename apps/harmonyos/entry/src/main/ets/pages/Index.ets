import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { THEME, ColorScheme } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';

@Entry
@ComponentV2
struct Index {
  @Local scheme: ColorScheme = 'light';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    void this.boot();
  }

  private async boot(): Promise<void> {
    try {
      await workspaceStore.loadFromStorage();
      await authStore.initialize();
      const state = authStore.getState();
      if (state.state === 'authed') {
        workspaceStore.fetchWorkspaces().catch((err: Error) => {
          console.warn('[index] workspace fetch on boot failed', err);
        });
        appNavigation.replaceName('WorkspaceLayout');
      } else {
        appNavigation.replaceName('LoginPage');
      }
    } catch (err) {
      console.error('[index] boot failed', err);
      appNavigation.replaceName('LoginPage');
    }
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Navigation(appNavigation.stack) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          MulticaText({
            value: 'Multica',
            scheme: this.scheme,
            size: '2xl',
            weight: 'bold',
            color: 'foreground'
          })
          MulticaText({
            value: 'AI-native task management',
            scheme: this.scheme,
            size: 'sm',
            color: 'mutedForeground'
          })
            .margin({ top: 8 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(THEME[this.scheme].background))
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }
}
