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
 * v0.5 design (fixes Bug 2 + Bug 3 from the v0.4 review):
 *
 * The root content is ALWAYS `WorkspaceLayout`. This makes
 * "navigate back to the main shell" trivial — `appNavigation.clearStack()`
 * returns the user to the root, which already shows the workspace
 * shell with its tab bar.
 *
 * - Authed user: root renders WorkspaceLayout, which shows its
 *   workspace content (Inbox/My Issues/Chat/More tabs).
 * - Unauthed user: after `boot()` runs, we call
 *   `appNavigation.pushName('LoginPage')` to overlay the login
 *   destination on top of the root. The user sees LoginPage;
 *   cancelling the auth flow pops back to the root, which the
 *   unauthed WorkspaceLayout replaces with another push.
 *
 * The v0.4 design tried to switch the root content between
 * WorkspaceLayout and LoginPage based on `initialRoute` state. That
 * was buggy: `initialRoute` only flipped once on mount, so an
 * auth:required event after sign-out had no path back to the login
 * page. Pushing LoginPage onto the destination stack is the
 * right tool here.
 */
@Entry
@ComponentV2
struct Index {
  @Local scheme: ColorScheme = 'light';
  @Local bootstrapping: boolean = true;

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
        // WorkspaceLayout's own bootstrap will fetch the workspace
        // list and pick the current workspace. We just need to make
        // sure the boot is done before the user sees the shell.
        workspaceStore.fetchWorkspaces().catch((err: Error) => {
          console.warn('[index] workspace fetch on boot failed', err);
        });
      } else {
        // Overlay the login destination on top of the root
        // WorkspaceLayout. The destination builder is registered by
        // the time build() returns, so this push lands cleanly.
        appNavigation.pushName('LoginPage');
      }
    } catch (err) {
      console.error('[index] boot failed', err);
      // On any boot failure, fall through to login.
      appNavigation.pushName('LoginPage');
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
        // Brief splash while boot() resolves. The destination builder
        // (PageDestinations) handles anything pushed on top.
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
      } else {
        // The root content is always WorkspaceLayout — the tab bar
        // + tab content for authed users, or a self-recovering
        // shell for unauthed users (it pushes LoginPage on top).
        WorkspaceLayout()
      }
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .navDestination(PageDestinations)
  }
}
