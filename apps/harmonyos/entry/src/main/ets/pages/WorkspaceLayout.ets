import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { globalEvents } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { ColorScheme, RADIUS, TextColorKey, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme, onThemePreferenceChanged } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { InboxPage } from './InboxPage';
import { MyIssuesPage } from './MyIssuesPage';
import { ChatPage } from './ChatPage';
import { MorePage } from './MorePage';

const TAB_LABELS: Record<string, string> = {
  'app.string.nav_inbox': 'Inbox',
  'app.string.nav_my_issues': 'My Issues',
  'app.string.nav_chat': 'Chat',
  'app.string.nav_more': 'More'
};

@ComponentV2
export struct WorkspaceLayout {
  @Local activeTab: number = 0;
  @Local scheme: ColorScheme = 'light';
  @Local bootstrapping: boolean = true;
  private authUnsub?: () => void;
  private wsUnsub?: () => void;
  private authStateUnsub?: () => void;
  private themeUnsub?: () => void;
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
    this.themeUnsub = onThemePreferenceChanged(() => {
      this.scheme = this.detectScheme();
    });
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
    this.themeUnsub?.();
    wsClient.disconnect();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
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
      this.TabButton(0, TAB_LABELS['app.string.nav_inbox'], '◐')
      this.TabButton(1, TAB_LABELS['app.string.nav_my_issues'], '◎')
      this.TabButton(2, TAB_LABELS['app.string.nav_chat'], '✦')
      this.TabButton(3, TAB_LABELS['app.string.nav_more'], '≡')
    }
    .width('100%')
    .padding({ left: space('2'), right: space('2'), top: space('1.5'), bottom: space('2') })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .border({
      width: { top: 1 },
      color: String(themeTokens(this.scheme).border)
    })
  }

  @Builder TabButton(index: number, label: string, glyph: string) {
    Column() {
      MulticaText({
        value: glyph,
        scheme: this.scheme,
        textSize: 'md',
        weight: this.activeTab === index ? 'bold' : 'medium',
        color: this.tabColorKey(index)
      })

      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'xs',
        weight: this.activeTab === index ? 'semibold' : 'normal',
        color: this.tabColorKey(index)
      })
        .margin({ top: 2 })
    }
    .layoutWeight(1)
    .padding({ top: 6, bottom: 6 })
    .borderRadius(RADIUS.md)
    .backgroundColor(this.activeTab === index ? String(themeTokens(this.scheme).card) : 'transparent')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .onClick(() => { this.activeTab = index; })
  }

  private tabColorKey(index: number): TextColorKey {
    return this.activeTab === index ? 'foreground' : 'mutedForeground';
  }
}
