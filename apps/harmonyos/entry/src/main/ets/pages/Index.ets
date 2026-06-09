import router from '@ohos.router';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { THEME, ColorScheme } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';

/**
 * Boot page. Resolves in three ticks:
 *   1. Wait for authStore.initialize() — checks secure storage for a
 *      token and refreshes the user record via /api/me.
 *   2. If authed, fetch the workspace list and pick the current.
 *   3. Route to LoginPage or WorkspaceLayout.
 *
 * The page renders a centered splash while the checks run. We don't
 * block the splash on the workspace fetch — if the user is authed but
 * their workspace list is slow, we still route them to WorkspaceLayout
 * which shows its own per-tab loading state. This matches iOS, where
 * the boot sequence is also "auth → main shell, fetch in shell".
 */
@Entry
@Component
struct Index {
  @State scheme: ColorScheme = 'light';

  aboutToAppear(): void {
    authStore.subscribe(() => { /* state changes don't drive this view; we use a one-shot check below */ });
    this.scheme = this.detectScheme();
    void this.boot();
  }

  private async boot(): Promise<void> {
    try {
      await workspaceStore.loadFromStorage();
      await authStore.initialize();
      const state = authStore.getState();
      if (state.state === 'authed') {
        // Pre-fetch workspace list in the background — don't await before
        // routing, the WorkspaceLayout page will pick up the result via
        // its own subscription.
        workspaceStore.fetchWorkspaces().catch((err: Error) => {
          console.warn('[index] workspace fetch on boot failed', err);
        });
        router.replaceUrl({ url: 'pages/WorkspaceLayout' });
      } else {
        router.replaceUrl({ url: 'pages/LoginPage' });
      }
    } catch (err) {
      console.error('[index] boot failed', err);
      router.replaceUrl({ url: 'pages/LoginPage' });
    }
  }

  private detectScheme(): ColorScheme {
    // Hook for system color scheme detection. HarmonyOS exposes
    // @ohos.app.ability.ConfigurationConstant; for now we default to
    // 'light' and let the user override from settings.
    return 'light';
  }

  build() {
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
}
