import hilog from '@ohos.hilog';
import promptAction from '@ohos.promptAction';
import { appNavigation, navParam } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { Preferences } from '../data/preferences';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme, ThemePreference } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';

interface MenuItem {
  label: string;
  hint?: string;
  icon: string;
  onPress: () => void;
}

interface ThemeOption {
  value: ThemePreference;
  label: string;
}

class ActionMenuButton {
  text: string = '';
  color?: Color;
}

const THEME_OPTIONS: ThemeOption[] = [
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'system', label: 'System' }
];

const MORE_DEBUG_DOMAIN = 0xFF13;
const MORE_DEBUG_TAG = 'MorePage';

@ComponentV2
export struct MorePage {
  @Local scheme: ColorScheme = 'light';
  @Local userName: string = '';
  @Local userEmail: string = '';
  @Local workspaceName: string = '';
  @Local logoutError: string = '';
  @Local themePref: ThemePreference = 'system';

  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(MORE_DEBUG_DOMAIN, MORE_DEBUG_TAG,
      `stage=${stage} workspaceId=${workspaceStore.currentId ?? 'null'} workspaceSlug=${workspaceStore.currentSlug ?? 'null'} ${extra}`);
  }

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
    this.themePref = Preferences.getThemePref();
  }

  private async setThemePreference(pref: ThemePreference): Promise<void> {
    try {
      await Preferences.setThemePref(pref);
      this.themePref = pref;
      this.scheme = this.detectScheme();
    } catch (err) {
      this.logoutError = err instanceof Error ? err.message : 'Failed to update appearance';
    }
  }

  private makeActionButton(text: string): promptAction.Button {
    const button: promptAction.Button = { text } as promptAction.Button;
    return button;
  }

  private async confirmLogout(): Promise<void> {
    const buttons: [promptAction.Button, promptAction.Button] = [
      this.makeActionButton('Cancel'),
      this.makeActionButton('Sign out')
    ];
    try {
      const result = await promptAction.showActionMenu({
        title: 'Sign out',
        buttons
      });
      if (result && result.index === 1) {
        await this.logout();
      }
    } catch (err) {
      this.logoutError = err instanceof Error ? err.message : 'Sign-out failed — please try again';
    }
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

  private onSwitchWorkspace(): void {
    appNavigation.pushName('SwitchWorkspacePage');
  }

  private onOpenProfile(): void {
    appNavigation.pushName('ProfilePage');
  }

  private onOpenNotifications(): void {
    appNavigation.pushName('NotificationsPage');
  }

  private searchMenuItems(): MenuItem[] {
    return [
      { label: 'Projects', hint: 'Browse projects', icon: '◫', onPress: () => { this.debugInfo('tap-projects', 'target=ProjectsPage'); appNavigation.pushName('ProjectsPage'); } },
      { label: 'Issues', hint: 'Browse issues', icon: '☰', onPress: () => { this.debugInfo('tap-issues', 'target=IssuesPage'); appNavigation.pushName('IssuesPage'); } },
      { label: 'Pinned', hint: 'Pinned items', icon: '⌘', onPress: () => { this.debugInfo('tap-pinned', 'target=SearchPage tab=pins'); appNavigation.pushName('SearchPage', navParam('tab', 'pins')); } },
      { label: 'Agents', hint: 'Browse agents', icon: '✦', onPress: () => { this.debugInfo('tap-agents', 'target=AgentsPage'); appNavigation.pushName('AgentsPage'); } }
    ];
  }

  build() {
    Column() {
      Header({ title: 'Settings', scheme: this.scheme })

      Scroll() {
        Column() {
          this.AccountSection()
          this.WorkspacesSection()
          this.AppearanceSection()

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
          .backgroundColor(String(themeTokens(this.scheme).card))
          .borderRadius(RADIUS.xl)
          .border({ width: 1, color: String(themeTokens(this.scheme).border) })
          .margin({ left: space('3'), right: space('3'), top: space('5'), bottom: space('5') })
          .onClick(() => { void this.confirmLogout(); })
        }
        .width('100%')
        .padding({ top: space('2') })
        .backgroundColor(String(themeTokens(this.scheme).background))
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder AccountSection() {
    Column() {
      this.SectionTitle('Account')
      Column() {
        this.ProfileRow()
        this.Divider()
        this.SimpleNavRow('Notifications', 'Inbox and system alerts', () => { this.onOpenNotifications(); })
      }
      .width('100%')
      .backgroundColor(String(themeTokens(this.scheme).card))
      .borderRadius(RADIUS.xl)
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
    }
    .width('100%')
    .margin({ left: space('3'), right: space('3') })
  }

  @Builder ProfileRow() {
    Row() {
      Avatar({ name: this.userName, url: authStore.getState().user?.avatar_url ?? '', avatarSize: 40, scheme: this.scheme })
      Column() {
        MulticaText({
          value: 'Profile',
          scheme: this.scheme,
          textSize: 'sm',
          weight: 'medium',
          color: 'foreground'
        })
        MulticaText({
          value: this.userName || '—',
          scheme: this.scheme,
          textSize: 'xs',
          color: 'mutedForeground'
        })
          .margin({ top: 2 })
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
    .onClick(() => { this.onOpenProfile(); })
  }

  @Builder WorkspacesSection() {
    Column() {
      this.SectionTitle('Workspaces')
      Column() {
        this.SimpleNavRow(this.workspaceName || 'No workspace selected', workspaceStore.currentSlug ? `/${workspaceStore.currentSlug}` : undefined, () => { this.onSwitchWorkspace(); })
      }
      .width('100%')
      .backgroundColor(String(themeTokens(this.scheme).card))
      .borderRadius(RADIUS.xl)
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
    }
    .width('100%')
    .margin({ left: space('3'), right: space('3'), top: space('3') })
  }

  @Builder AppearanceSection() {
    Column() {
      this.SectionTitle('Appearance')
      Column() {
        ForEach(THEME_OPTIONS, (opt: ThemeOption, index: number) => {
          Row() {
            MulticaText({
              value: opt.label,
              scheme: this.scheme,
              textSize: 'sm',
              weight: 'medium',
              color: 'foreground'
            })
            Blank()
            MulticaText({
              value: this.themePref === opt.value ? '✓' : '',
              scheme: this.scheme,
              textSize: 'sm',
              weight: 'semibold',
              color: 'brand'
            })
          }
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('3.5'), bottom: space('3.5') })
          .border(index < THEME_OPTIONS.length - 1 ? {
            width: { bottom: 1 },
            color: String(themeTokens(this.scheme).border)
          } : undefined)
          .onClick(() => { void this.setThemePreference(opt.value); })
        })
      }
      .width('100%')
      .backgroundColor(String(themeTokens(this.scheme).card))
      .borderRadius(RADIUS.xl)
      .border({ width: 1, color: String(themeTokens(this.scheme).border) })
    }
    .width('100%')
    .margin({ left: space('3'), right: space('3'), top: space('3') })
  }

  @Builder SectionTitle(title: string) {
    Row() {
      MulticaText({
        value: title,
        scheme: this.scheme,
        textSize: 'xs',
        color: 'mutedForeground',
        weight: 'semibold'
      })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ left: space('4') })
    .margin({ bottom: space('2') })
  }

  @Builder Divider() {
    Row() {}
      .width('100%')
      .height(1)
      .backgroundColor(String(themeTokens(this.scheme).border))
  }

  @Builder SimpleNavRow(title: string, subtitle: string | undefined, onPress: () => void) {
    Row() {
      Column() {
        MulticaText({
          value: title,
          scheme: this.scheme,
          textSize: 'sm',
          weight: 'medium',
          color: 'foreground'
        })
        if (subtitle) {
          MulticaText({
            value: subtitle,
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
            .margin({ top: 2 })
        }
      }
      .layoutWeight(1)
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
    .onClick(() => { onPress(); })
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
          .backgroundColor(String(themeTokens(this.scheme).card))
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
          color: String(themeTokens(this.scheme).border)
        } : undefined)
        .onClick(() => { item.onPress(); })
      })
    }
    .width('100%')
    .backgroundColor(String(themeTokens(this.scheme).card))
    .borderRadius(RADIUS.xl)
    .border({ width: 1, color: String(themeTokens(this.scheme).border) })
  }
}
