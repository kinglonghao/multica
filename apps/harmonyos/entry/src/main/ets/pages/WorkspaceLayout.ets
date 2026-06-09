import { appNavigation } from '../data/navigation';
import { globalEvents } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { THEME, ColorScheme, SPACE, textColor, TextColorKey } from '../lib/theme';
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

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.authUnsub = globalEvents.on('auth:required', () => {
      appNavigation.replaceName('LoginPage');
    });
    this.wsUnsub = globalEvents.on('workspace:changed', () => {
      this.recheckWorkspace();
    });
    this.bootRealtime();
    void this.bootstrap();
  }

  aboutToDisappear(): void {
    this.authUnsub?.();
    this.wsUnsub?.();
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
      appNavigation.replaceName('SelectWorkspacePage');
    }
  }

  build() {
    if (this.bootstrapping) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          Skeleton({ scheme: this.scheme, width: 200, height: 24, radius: 6 })
          Skeleton({ scheme: this.scheme, width: 120, height: 16, radius: 4 })
            .margin({ top: SPACE['2'] })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(THEME[this.scheme].background))
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
      .backgroundColor(String(THEME[this.scheme].background))
    }
  }

  @Builder TabBar() {
    Row() {
      this.TabButton(0, $r('app.string.nav_inbox'), $r('sys.symbol.tray_fill'))
      this.TabButton(1, $r('app.string.nav_my_issues'), $r('sys.symbol.checkmark_square'))
      this.TabButton(2, $r('app.string.nav_chat'), $r('sys.symbol.bubble_left_fill'))
      this.TabButton(3, $r('app.string.nav_more'), $r('sys.symbol.line_3_horizontal'))
    }
    .width('100%')
    .height(56)
    .backgroundColor(String(THEME[this.scheme].background))
    .border({
      width: { top: 1 },
      color: String(THEME[this.scheme].border)
    })
  }

  @Builder TabButton(index: number, label: Resource, glyph: Resource) {
    Column() {
      SymbolGlyph(glyph)
        .fontSize(20)
        .fontColor([textColor(this.scheme, this.tabColorKey(index))])
      MulticaText({
        value: this.resolveLabel(label),
        scheme: this.scheme,
        size: 'xs',
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
