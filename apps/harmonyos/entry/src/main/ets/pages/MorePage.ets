import { appNavigation } from '../data/navigation';
import { authStore } from '../data/auth';
import { workspaceStore } from '../data/workspace';
import { wsClient } from '../realtime/ws-client';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { themeController } from '../lib/theme-controller';
import { t } from '../lib/locale';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Avatar } from '../components/ui/Avatar';
import { WorkspaceAvatar } from '../components/workspace/WorkspaceAvatar';
import { MulticaButton } from '../components/ui/Button';

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
  @Local workspaceSlug: string = '';
  @Local logoutError: string = '';
  @Local signingOut: boolean = false;
  private themeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.refreshUser();
  }

  aboutToDisappear(): void {
    this.themeUnsub?.();
  }

  private refreshUser(): void {
    const state = authStore.getState();
    this.userName = state.user?.display_name ?? state.user?.email ?? 'User';
    this.userEmail = state.user?.email ?? '';
    const ws = workspaceStore.getState().current;
    this.workspaceName = ws?.name ?? '';
    this.workspaceSlug = ws?.slug ?? '';
  }

  private async logout(): Promise<void> {
    this.signingOut = true;
    this.logoutError = '';
    try {
      wsClient.disconnect();
      await workspaceStore.clear();
      await authStore.logout();
      appNavigation.clearStack();
      appNavigation.pushName('LoginPage');
    } catch (err) {
      this.logoutError = err instanceof Error ? err.message : t('more_sign_out_failed');
    } finally {
      this.signingOut = false;
    }
  }

  build() {
    Column() {
      Header({ title: t('more_title'), scheme: this.scheme })

      Scroll() {
        Column() {
          // ---- User card ----
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

          // ---- Workspace banner ----
          if (this.workspaceName) {
            Row() {
              WorkspaceAvatar({
                name: this.workspaceName,
                slug: this.workspaceSlug,
                scheme: this.scheme,
                size: 32
              })
              Column() {
                MulticaText({
                  value: this.workspaceName,
                  scheme: this.scheme,
                  size: 'sm',
                  weight: 'medium',
                  color: 'foreground'
                })
                MulticaText({
                  value: `/${this.workspaceSlug}`,
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
            .borderRadius(RADIUS.lg)
            .backgroundColor(String(THEME[this.scheme].card))
            .margin({ top: SPACE['2'] })
            .onClick(() => { appNavigation.pushName('SwitchWorkspacePage'); })
          }

          // ---- Settings entry ----
          Row() {
            MulticaText({
              value: '⚙',
              scheme: this.scheme,
              size: 'lg',
              color: 'foreground'
            })
            MulticaText({
              value: t('common_settings'),
              scheme: this.scheme,
              size: 'base',
              weight: 'medium',
              color: 'foreground'
            })
              .margin({ left: SPACE['3'] })
            Blank()
            MulticaText({
              value: '›',
              scheme: this.scheme,
              size: 'lg',
              color: 'mutedForeground'
            })
          }
          .width('100%')
          .padding(SPACE['4'])
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))
          .margin({ top: SPACE['4'] })
          .onClick(() => { appNavigation.pushName('SettingsPage'); })

          // ---- Navigate section ----
          MulticaText({
            value: t('more_section_navigate'),
            scheme: this.scheme,
            size: 'xs',
            weight: 'semibold',
            color: 'mutedForeground'
          })
            .width('100%')
            .padding({ left: SPACE['1'], top: SPACE['6'], bottom: SPACE['2'] })

          Column() {
            this.MenuList([
              { label: t('more_projects'), onPress: () => appNavigation.pushName('SearchPage', { tab: 'projects' }) },
              { label: t('more_issues'), onPress: () => appNavigation.pushName('SearchPage', { tab: 'issues' }) },
              { label: t('more_pinned'), onPress: () => appNavigation.pushName('SearchPage', { tab: 'pins' }) },
              { label: t('more_agents'), onPress: () => appNavigation.pushName('AgentsPage') },
              { label: t('more_notifications'), onPress: () => appNavigation.pushName('NotificationsPage') },
              { label: t('more_profile'), onPress: () => appNavigation.pushName('ProfilePage') }
            ])
          }
          .width('100%')
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].card))
          .clip(true)

          if (this.logoutError) {
            MulticaText({
              value: this.logoutError,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .width('100%')
              .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['2'] })
          }

          // ---- Sign out ----
          MulticaButton({
            label: this.signingOut ? '…' : t('common_sign_out'),
            scheme: this.scheme,
            variant: 'destructive',
            fullWidth: true,
            disabled: this.signingOut,
            onTap: () => { void this.logout(); }
          })
            .margin({ top: SPACE['6'], bottom: SPACE['6'] })
        }
        .padding(SPACE['4'])
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder MenuList(items: MenuItem[]) {
    Column() {
      ForEach(items, (item: MenuItem, idx: number) => {
        Row() {
          MulticaText({
            value: item.label,
            scheme: this.scheme,
            size: 'base',
            color: 'foreground'
          })
          Blank()
          MulticaText({
            value: '›',
            scheme: this.scheme,
            size: 'lg',
            color: 'mutedForeground'
          })
        }
        .width('100%')
        .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
        .onClick(() => { item.onPress(); })
        if (idx < items.length - 1) {
          Row()
            .width('100%')
            .height(1)
            .backgroundColor(String(THEME[this.scheme].border))
            .margin({ left: SPACE['4'] })
        }
      })
    }
    .width('100%')
  }
}
