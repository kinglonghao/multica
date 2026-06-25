import hilog from '@ohos.hilog';
import { appNavigation, navParam } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';

interface MenuItem {
  label: string;
  hint?: string;
  icon: string;
  onPress: () => void;
}

const MORE_DEBUG_DOMAIN = 0xFF13;
const MORE_DEBUG_TAG = 'MorePage';

@ComponentV2
export struct MorePage {
  @Local scheme: ColorScheme = 'light';
  @Local userName: string = '';
  @Local userEmail: string = '';
  @Local workspaceName: string = '';
  @Local logoutError: string = '';

  // #region debug-point A:more-page-entry
  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(MORE_DEBUG_DOMAIN, MORE_DEBUG_TAG,
      `stage=${stage} workspaceId=${workspaceStore.currentId ?? 'null'} workspaceSlug=${workspaceStore.currentSlug ?? 'null'} ${extra}`);
  }
  // #endregion

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.refreshUser();
    this.debugInfo('aboutToAppear', `workspaceName=${this.workspaceName || 'empty'}`);
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private refreshUser(): void {
    const state = authStore.getState();
    this.userName = state.user?.display_name ?? state.user?.email ?? 'User';
    this.userEmail = state.user?.email ?? '';
    this.workspaceName = workspaceStore.getState().current?.name ?? '';
  }

  private async logout(): Promise<void> {
    try {
      wsClient.disconnect();
      await workspaceStore.clear();
      await authStore.logout();
      appNavigation.clear();
      appNavigation.pushName('LoginPage');
    } catch (err) {
      this.logoutError = err instanceof Error ? err.message : 'Sign-out failed — please try again';
    }
  }

  private searchMenuItems(): MenuItem[] {
    return [
      { label: 'Projects', hint: '查看项目', icon: '◫', onPress: () => { this.debugInfo('tap-projects', 'target=ProjectsPage'); appNavigation.pushName('ProjectsPage'); } },
      { label: 'Issues', hint: '浏览任务', icon: '☰', onPress: () => { this.debugInfo('tap-issues', 'target=IssuesPage'); appNavigation.pushName('IssuesPage'); } },
      { label: 'Pinned', hint: '固定内容', icon: '⌘', onPress: () => { this.debugInfo('tap-pinned', 'target=SearchPage tab=pins'); appNavigation.pushName('SearchPage', navParam('tab', 'pins')); } },
      { label: 'Agents', hint: '智能体', icon: '✦', onPress: () => { this.debugInfo('tap-agents', 'target=AgentsPage'); appNavigation.pushName('AgentsPage'); } },
      { label: 'Notifications', hint: '通知中心', icon: '◉', onPress: () => { this.debugInfo('tap-notifications', 'target=NotificationsPage'); appNavigation.pushName('NotificationsPage'); } },
      { label: 'Profile', hint: '个人资料', icon: '◌', onPress: () => { this.debugInfo('tap-profile', 'target=ProfilePage'); appNavigation.pushName('ProfilePage'); } },
      { label: 'Switch workspace', hint: '切换空间', icon: '⇄', onPress: () => { this.debugInfo('tap-switch-workspace', 'target=SwitchWorkspacePage'); appNavigation.pushName('SwitchWorkspacePage'); } }
    ];
  }

  build() {
    Column() {
      Header({ title: 'More', scheme: this.scheme })

      Scroll() {
        Column() {
          this.ProfileCard()

          Column() {
            this.MenuList(this.searchMenuItems())
          }
          .margin({ left: space('3'), right: space('3'), top: space('3') })

          if (this.logoutError) {
            MulticaText({
              value: this.logoutError,
              scheme: this.scheme,
              textSize: 'sm',
              color: 'destructive'
            })
              .margin({ left: space('3'), right: space('3'), top: space('3') })
          }

          Row() {
            MulticaText({
              value: 'Sign out',
              scheme: this.scheme,
              textSize: 'sm',
              weight: 'semibold',
              color: 'destructive'
            })
          }
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
          .backgroundColor('#FFF5F5')
          .borderRadius(RADIUS.xl)
          .border({ width: 1, color: '#FECACA' })
          .margin({ left: space('3'), right: space('3'), top: space('5'), bottom: space('5') })
          .onClick(() => { void this.logout(); })
        }
        .width('100%')
        .padding({ top: space('2') })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F7F7F8')
  }

  @Builder ProfileCard() {
    Column() {
      Row() {
        Avatar({ name: this.userName, url: '', avatarSize: 52, scheme: this.scheme })
        Column() {
          MulticaText({
            value: this.userName,
            scheme: this.scheme,
            textSize: 'base',
            weight: 'semibold',
            color: 'foreground'
          })
          MulticaText({
            value: this.userEmail,
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
            .margin({ top: 3 })
        }
        .layoutWeight(1)
        .margin({ left: space('3') })
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      if (this.workspaceName) {
        Row() {
          Column() {
            MulticaText({
              value: '当前空间',
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground'
            })
            MulticaText({
              value: this.workspaceName,
              scheme: this.scheme,
              textSize: 'sm',
              weight: 'semibold',
              color: 'foreground'
            })
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row() {
            MulticaText({
              value: 'Manage',
              scheme: this.scheme,
              textSize: 'xs',
              weight: 'semibold',
              color: 'brand'
            })
          }
          .padding({ left: space('3'), right: space('3'), top: space('2'), bottom: space('2') })
          .backgroundColor('#EEF2FF')
          .borderRadius(RADIUS.full)
        }
        .width('100%')
        .margin({ top: space('4') })
      }
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
    .margin({ left: space('3'), right: space('3'), top: space('3') })
    .backgroundColor('#FFFFFF')
    .borderRadius(RADIUS.xl)
    .border({ width: 1, color: '#ECECF1' })
    .onClick(() => { appNavigation.pushName('ProfilePage'); })
  }

  @Builder MenuList(items: MenuItem[]) {
    Column() {
      ForEach(items, (item: MenuItem, index: number) => {
        Row() {
          Row() {
            MulticaText({
              value: item.icon,
              scheme: this.scheme,
              textSize: 'sm',
              color: 'foreground'
            })
          }
          .width(34)
          .height(34)
          .borderRadius(10)
          .backgroundColor('#F4F4F5')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)

          Column() {
            MulticaText({
              value: item.label,
              scheme: this.scheme,
              textSize: 'sm',
              weight: 'medium',
              color: 'foreground'
            })
            if (item.hint) {
              MulticaText({
                value: item.hint,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
                .margin({ top: 2 })
            }
          }
          .layoutWeight(1)
          .margin({ left: space('3') })
          .alignItems(HorizontalAlign.Start)

          MulticaText({
            value: '›',
            scheme: this.scheme,
            textSize: 'base',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .padding({ left: space('4'), right: space('4'), top: space('3.5'), bottom: space('3.5') })
        .border(index < items.length - 1 ? {
          width: { bottom: 1 },
          color: '#ECECF1'
        } : undefined)
        .onClick(() => { item.onPress(); })
      })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
    .borderRadius(RADIUS.xl)
    .border({ width: 1, color: '#ECECF1' })
  }
}
