import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { globalEvents } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { THEME, ColorScheme, SPACE, textColor, TextColorKey, space, themeTokens } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { InboxPage } from './InboxPage';
import { MyIssuesPage } from './MyIssuesPage';
import { ChatPage } from './ChatPage';
import { MorePage } from './MorePage';

@ComponentV2
export struct WorkspaceLayout {
  @Local activeTab: number = 0;
  @Local scheme: ColorScheme = 'light';
  @Local bootstrapping: boolean = true;
  private authUnsub?: () => void;
  private wsUnsub?: () => void;
  // Bug 12 fix: subscribe to authStore state so that when the user
  // completes the OTP flow (LoginPage → VerifyPage → clear stack),
  // we kick off bootstrap even though aboutToAppear already ran
  // with state='uninitialized' and returned early. Without this
  // subscription, fetchWorkspaces() never runs on first login,
  // workspaceSlug stays null, and every /api/* request returns
  // 400 because X-Workspace-Slug is undefined.
  private authStateUnsub?: () => void;
  private bootStarted: boolean = false;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.authUnsub = globalEvents.on('auth:required', () => {
      appNavigation.clear();
      appNavigation.pushName('LoginPage');
    });
    this.wsUnsub = globalEvents.on('workspace:changed', () => {
      this.recheckWorkspace();
    });
    this.authStateUnsub = authStore.subscribe((s) => {
      if (s.state === 'authed' && !this.bootStarted) {
        this.bootStarted = true;
        this.bootRealtime();
        void this.bootstrap();
      }
    });
    // Bug 2 fix: if the user is unauthed when this shell mounts,
    // immediately overlay the login destination. Without this, the
    // user lands on a permanent skeleton (the auth:required event
    // never fires because there's nothing to invalidate).
    if (authStore.getState().state !== 'authed') {
      appNavigation.pushName('LoginPage');
      this.bootstrapping = false;
      return;
    }
    this.bootStarted = true;
    this.bootRealtime();
    void this.bootstrap();
  }

  aboutToDisappear(): void {
    this.authUnsub?.();
    this.wsUnsub?.();
    this.authStateUnsub?.();
    // Disconnect the WS on leave so a forced sign-out (auth:required)
    // doesn't leave the socket connected and continuing to receive
    // events for a workspace the user no longer has access to.
    // The earlier code only disconnected on explicit logout, which
    // meant the socket could outlive the auth session and silently
    // fail the 401 path on every reconnect.
    wsClient.disconnect();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private bootRealtime(): void {
    wsClient.connect();
  }

  private async bootstrap(): Promise<void> {
    try {
      const list = await workspaceStore.fetchWorkspaces();
      if (list.length === 0) {
        appNavigation.replaceName('SelectWorkspacePage');
        return;
      }
      this.bootstrapping = false;
    } catch (err) {
      console.warn('[workspace-layout] bootstrap failed', err);
      this.bootstrapping = false;
    }
  }

  private recheckWorkspace(): void {
    if (!workspaceStore.currentId) {
      appNavigation.clear();
      appNavigation.pushName('SelectWorkspacePage');
    }
  }

  build() {
    if (this.bootstrapping) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Skeleton({ scheme: this.scheme, skeletonWidth: 200, skeletonHeight: 24, radius: 6 })
          Skeleton({ scheme: this.scheme, skeletonWidth: 120, skeletonHeight: 16, radius: 4 })
            .margin({ top: space('2') })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(themeTokens(this.scheme).background))
    } else {
      Column() {
        Stack() {
          if (this.activeTab === 0) {
            InboxPage();
          } else if (this.activeTab === 1) {
            MyIssuesPage();
          } else if (this.activeTab === 2) {
            ChatPage();
          } else {
            MorePage();
          }
        }
        .layoutWeight(1)
        .width('100%')

        this.TabBar()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(themeTokens(this.scheme).background))
    }
  }

  @Builder TabBar() {
    Row() {
      this.TabButton(0, $r('app.string.nav_inbox'), 'I')
      this.TabButton(1, $r('app.string.nav_my_issues'), 'T')
      this.TabButton(2, $r('app.string.nav_chat'), 'C')
      this.TabButton(3, $r('app.string.nav_more'), 'M')
    }
    .width('100%')
    .height(56)
    .backgroundColor(String(themeTokens(this.scheme).background))
    .border({
      width: { top: 1 },
      color: String(themeTokens(this.scheme).border)
    })
  }

  @Builder TabButton(index: number, label: Resource, glyph: string) {
    Column() {
      MulticaText({
        value: glyph,
        scheme: this.scheme,
        textSize: 'base',
        weight: 'bold',
        color: this.tabColorKey(index)
      })
      MulticaText({
        value: this.resolveLabel(label),
        scheme: this.scheme,
        textSize: 'xs',
        color: this.tabColorKey(index)
      })
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.activeTab = index; })
  }

  /**
   * Compute the TextColorKey for the tab at `index` based on whether
   * it's the active tab. Returning the typed `TextColorKey` lets
   * `textColor()` pick the value statically — no dynamic bracket
   * access.
   */
  private tabColorKey(index: number): TextColorKey {
    return this.activeTab === index ? 'foreground' : 'mutedForeground';
  }

  /**
   * Resolve a `Resource` to its string form via the resource manager.
   * Replaces the v0.2 `as unknown as string` double cast (C-5).
   */
  private resolveLabel(r: Resource): string {
    try {
      return getContext(this).resourceManager.getStringSync(r);
    } catch {
      return '';
    }
  }
}
