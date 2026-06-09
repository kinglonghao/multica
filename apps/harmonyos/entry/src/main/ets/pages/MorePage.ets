import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';

interface MenuItem {
  label: string;
  onPress: () => void;
}

@ComponentV2
export struct MorePage {
  @Local scheme: ColorScheme = 'light';
  @Local userName: string = '';
  @Local userEmail: string = '';
  @Local workspaceName: string = '';
  @Local logoutError: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.refreshUser();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private refreshUser(): void {
    const state = authStore.getState();
    this.userName = state.user?.display_name ?? state.user?.email ?? 'User';
    this.userEmail = state.user?.email ?? '';
    this.workspaceName = workspaceStore.getState().current?.name ?? '';
  }

  private async logout(): Promise<void> {
    // M-5: wrap in try/catch so a failed local clear doesn't leave
    // the user in a half-logged-out state with no UI affordance to
    // recover. The earlier v0.2 code had no try/catch and could leave
    // the UI on the More tab with an unusable auth state.
    try {
      wsClient.disconnect();
      await workspaceStore.clear();
      await authStore.logout();
      // Same pattern as Bug 3 fix — clear to root, then push
      // LoginPage on top so the unauthed state has a visible UI.
      appNavigation.clearStack();
      appNavigation.pushName('LoginPage');
    } catch (err) {
      this.logoutError = err instanceof Error ? err.message : 'Sign-out failed — please try again';
    }
  }

  build() {
    Column() {
      Header({ title: 'More', scheme: this.scheme })

      Row() {
        Avatar({ name: this.userName, url: '', size: 48, scheme: this.scheme })
        Column() {
          MulticaText({
            value: this.userName,
            scheme: this.scheme,
            size: 'base',
            weight: 'medium',
            color: 'foreground'
          })
          MulticaText({
            value: this.userEmail,
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['0.5'] })
        }
        .layoutWeight(1)
        .margin({ left: SPACE['3'] })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(SPACE['4'])
      .onClick(() => { appNavigation.pushName('ProfilePage'); })

      if (this.workspaceName) {
        Row() {
          MulticaText({
            value: `Workspace: ${this.workspaceName}`,
            scheme: this.scheme,
            size: 'sm',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .padding({ left: SPACE['4'], right: SPACE['4'], bottom: SPACE['2'] })
        .onClick(() => { appNavigation.pushName('SwitchWorkspacePage'); })
      }

      this.MenuList([
        { label: 'Projects', onPress: () => appNavigation.pushName('SearchPage', { tab: 'projects' }) },
        { label: 'Issues', onPress: () => appNavigation.pushName('SearchPage', { tab: 'issues' }) },
        { label: 'Pinned', onPress: () => appNavigation.pushName('SearchPage', { tab: 'pins' }) },
        { label: 'Agents', onPress: () => appNavigation.pushName('AgentsPage') },
        { label: 'Notifications', onPress: () => appNavigation.pushName('NotificationsPage') },
        { label: 'Profile', onPress: () => appNavigation.pushName('ProfilePage') },
        { label: 'Switch workspace', onPress: () => appNavigation.pushName('SwitchWorkspacePage') }
      ])

      Blank()

      if (this.logoutError) {
        MulticaText({
          value: this.logoutError,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .margin({ left: SPACE['4'], right: SPACE['4'], bottom: SPACE['2'] })
      }

      Row() {
        MulticaText({
          value: 'Sign out',
          scheme: this.scheme,
          size: 'base',
          weight: 'medium',
          color: 'destructive',
          textAlign: TextAlign.Center
        })
      }
      .width('100%')
      .padding(SPACE['4'])
      .backgroundColor(String(THEME[this.scheme].card))
      .borderRadius(RADIUS.md)
      .margin({ left: SPACE['4'], right: SPACE['4'], bottom: SPACE['4'] })
      .onClick(() => { void this.logout(); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder MenuList(items: MenuItem[]) {
    Column() {
      ForEach(items, (item: MenuItem) => {
        Row() {
          MulticaText({
            value: item.label,
            scheme: this.scheme,
            size: 'base',
            color: 'foreground'
          })
        }
        .width('100%')
        .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
        .onClick(() => { item.onPress(); })
      })
    }
    .width('100%')
    .border({
      width: { top: 1, bottom: 1 },
      color: String(THEME[this.scheme].border)
    })
  }
}
