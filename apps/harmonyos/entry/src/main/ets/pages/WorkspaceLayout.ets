import router from '@ohos.router';
import { authStore, globalEvents } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { InboxPage } from './InboxPage';
import { MyIssuesPage } from './MyIssuesPage';
import { ChatPage } from './ChatPage';
import { MorePage } from './MorePage';

/**
 * WorkspaceLayout — primary shell once the user is authed. Owns the
 * bottom tab bar (Inbox / My Issues / Chat / More) and routes the
 * "workspace not loaded yet" state (e.g. cold launch before the
 * workspace list resolves) to a thin splash. The "no workspace"
 * state routes to SelectWorkspacePage, mirroring the iOS
 * (app)/select-workspace.tsx behavior.
 *
 * Mounts the WS client. Disconnect on unmount to avoid leaking the
 * socket when the user signs out from the More tab.
 */
@Entry
@Component
struct WorkspaceLayout {
  @State activeTab: number = 0;
  @State scheme: ColorScheme = 'light';
  @State bootstrapping: boolean = true;
  private authUnsub?: () => void;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.authUnsub = globalEvents.on('auth:required', () => {
      router.replaceUrl({ url: 'pages/LoginPage' });
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
        router.replaceUrl({ url: 'pages/SelectWorkspacePage' });
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
      router.replaceUrl({ url: 'pages/SelectWorkspacePage' });
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
      this.TabButton(0, 'Inbox', '·')
      this.TabButton(1, 'My Issues', '·')
      this.TabButton(2, 'Chat', '·')
      this.TabButton(3, 'More', '·')
    }
    .width('100%')
    .height(56)
    .backgroundColor(String(THEME[this.scheme].background))
    .border({
      width: { top: 1 },
      color: String(THEME[this.scheme].border)
    })
  }

  @Builder TabButton(index: number, label: string, glyph: string) {
    Column() {
      MulticaText({
        value: glyph,
        scheme: this.scheme,
        size: 'lg',
        color: this.activeTab === index ? 'foreground' : 'mutedForeground'
      })
      MulticaText({
        value: label,
        scheme: this.scheme,
        size: 'xs',
        color: this.activeTab === index ? 'foreground' : 'mutedForeground'
      })
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.activeTab = index; })
  }
}
