import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { THEME, ColorScheme } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { WorkspaceLayout } from './WorkspaceLayout';
import { PageDestinations } from './destinations';

/**
 * The ONE @Entry for the entire app. Hosts the single root
 * `Navigation(appNavigation.stack)` and the `navDestination()` registry
 * that maps logical page names to their component. All other pages
 * (LoginPage, IssueDetailPage, …) are plain `@ComponentV2` structs
 * with no `@Entry` decorator — they're mounted by `PageDestinations`.
 *
 * Boot flow:
 *   1. Load workspace from storage (sync) and call authStore.initialize
 *      which checks for a stored token and refreshes the user via /me.
 *   2. If authed, kick off `workspaceStore.fetchWorkspaces()` in the
 *      background and render the WorkspaceLayout (which shows a
 *      skeleton until the workspace list resolves).
 *   3. If not authed, push LoginPage.
 */
@Entry
@ComponentV2
struct Index {
  @Local scheme: ColorScheme = 'light';
  @Local bootstrapping: boolean = true;
  @Local initialRoute: 'WorkspaceLayout' | 'LoginPage' = 'LoginPage';

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
        this.initialRoute = 'WorkspaceLayout';
        workspaceStore.fetchWorkspaces().catch((err: Error) => {
          console.warn('[index] workspace fetch on boot failed', err);
        });
      } else {
        this.initialRoute = 'LoginPage';
      }
    } catch (err) {
      console.error('[index] boot failed', err);
      this.initialRoute = 'LoginPage';
    } finally {
      this.bootstrapping = false;
    }
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Navigation(appNavigation.stack) {
      if (this.bootstrapping) {
        Stack({ alignContent: Alignment.Center }) {
          MulticaText({
            value: 'Multica',
            scheme: this.scheme,
            size: '2xl',
            weight: 'bold',
            color: 'foreground'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(String(THEME[this.scheme].background))
      } else if (this.initialRoute === 'WorkspaceLayout') {
        WorkspaceLayout()
      } else {
        // LoginPage is mounted via the destination builder — the user
        // is unauthed, so the stack starts empty and the root content
        // shows the splash until the destination push lands.
        Stack({ alignContent: Alignment.Center }) {
          MulticaText({
            value: 'Multica',
            scheme: this.scheme,
            size: '2xl',
            weight: 'bold',
            color: 'foreground'
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor(String(THEME[this.scheme].background))
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(PageDestinations)
  }
}
