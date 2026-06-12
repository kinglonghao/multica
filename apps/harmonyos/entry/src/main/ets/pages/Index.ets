import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { THEME, ColorScheme } from '../lib/theme';
import { themeController } from '../lib/theme-controller';
import { localeController } from '../lib/locale';
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
 * v0.6 design (Bug fix on top of v0.5):
 *
 * v0.5 had a duplicate-push bug. Both `Index.boot()` and
 * `WorkspaceLayout.aboutToAppear` would call
 * `appNavigation.pushName('LoginPage')` for an unauthed user,
 * leaving the destination stack with [LoginPage, LoginPage]. A
 * single `pop()` would reveal a second LoginPage instead of
 * WorkspaceLayout.
 *
 * Fix: this page no longer owns the splash-vs-shell decision.
 * The root content is always `WorkspaceLayout`, and the auth
 * check lives in `WorkspaceLayout.aboutToAppear` only. Index
 * just kicks the workspace list fetch in the background.
 */
@Entry
@ComponentV2
struct Index {
  @Local scheme: ColorScheme = 'light';
  @Local localeVersion: number = 0;
  private themeUnsub?: () => void;
  private localeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.localeUnsub = localeController.subscribe(() => { this.localeVersion++; });
    void this.boot();
  }

  aboutToDisappear(): void {
    this.themeUnsub?.();
    this.localeUnsub?.();
  }

  private async boot(): Promise<void> {
    try {
      // We only need the workspace store's stored-current-workspace
      // so the API client can attach X-Workspace-Slug on its first
      // request. WorkspaceLayout's own bootstrap kicks off the
      // list fetch — Index doesn't need to.
      await workspaceStore.loadFromStorage();
      await authStore.initialize();
    } catch (err) {
      console.error('[index] boot failed', err);
    }
  }

  build() {
    Navigation(appNavigation.stack) {
      // Always WorkspaceLayout. The shell handles its own splash
      // (via its own `bootstrapping` flag) AND its own auth check
      // (via the aboutToAppear in WorkspaceLayout.ets). Index is
      // a thin shell around the navigation root.
      WorkspaceLayout()
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(PageDestinations)
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
