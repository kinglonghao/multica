import router from '@ohos.router';
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

@Component
export struct MorePage {
  @State scheme: ColorScheme = 'light';
  @State userName: string = '';
  @State userEmail: string = '';
  @State workspaceName: string = '';

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
    wsClient.disconnect();
    await workspaceStore.clear();
    await authStore.logout();
    router.replaceUrl({ url: 'pages/LoginPage' });
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
      .onClick(() => { router.pushUrl({ url: 'pages/ProfilePage' }); })

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
        .onClick(() => { router.pushUrl({ url: 'pages/SwitchWorkspacePage' }); })
      }

      this.MenuList([
        { label: 'Projects', onPress: () => router.pushUrl({ url: 'pages/SearchPage', params: { tab: 'projects' } }) },
        { label: 'Issues', onPress: () => router.pushUrl({ url: 'pages/SearchPage', params: { tab: 'issues' } }) },
        { label: 'Pinned', onPress: () => router.pushUrl({ url: 'pages/SearchPage', params: { tab: 'pins' } }) },
        { label: 'Agents', onPress: () => router.pushUrl({ url: 'pages/AgentsPage' }) },
        { label: 'Notifications', onPress: () => router.pushUrl({ url: 'pages/NotificationsPage' }) },
        { label: 'Profile', onPress: () => router.pushUrl({ url: 'pages/ProfilePage' }) },
        { label: 'Switch workspace', onPress: () => router.pushUrl({ url: 'pages/SwitchWorkspacePage' }) }
      ])

      Blank()

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
