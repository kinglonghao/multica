import { appNavigation, navParam } from '../data/navigation';
import { useInboxQuery } from '../queries/inbox';
import { useQuery, QueryHandle } from '../queries/cache';
import { useInboxRealtime } from '../realtime/realtime-hooks';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { deduplicateInboxItems } from '../lib/inbox-display';
import { markInboxRead, cloneInboxItem, markAllInboxRead, archiveAllInbox, archiveAllReadInbox, archiveCompletedInbox, archiveInboxItem } from '../mutations/inbox';
import { InboxItem, Issue } from '../models/types';
import { ColorScheme, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { InboxRow } from '../components/inbox/InboxRow';
import { MulticaButton } from '../components/ui/Button';

@ComponentV2
export struct InboxPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local issueCache: Map<string, Issue> = new Map();
  @Local _isLoading: boolean = true;
  @Local _data: InboxItem[] | undefined = undefined;
  @Local _error: Error | null = null;
  @Local menuVisible: boolean = false;
  @Local menuBusy: boolean = false;
  @Local swipingItemId: string = '';
  private query: QueryHandle<InboxItem[]> | null = null;
  private hydrationInFlight: Set<string> = new Set();
  private wsUnsub?: () => void;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useInboxQuery(() => {
      this.version++;
      this.syncFromCache();
      void this.hydrateIssueCache();
    });
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    void this.hydrateIssueCache();
    this.wsUnsub = useInboxRealtime();
  }

  private syncFromCache(): void {
    if (!this.query) return;
    const s = this.query.getState();
    this._isLoading = s.isLoading;
    this._data = s.data as InboxItem[] | undefined;
    this._error = s.error;
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private async hydrateIssueCache(): Promise<void> {
    if (!this.query) return;
    const state = this.query.getState();
    const items = state.data ?? [];
    const seen = new Set<string>();
    for (const item of items) {
      if (!item.issue_id) continue;
      if (this.issueCache.has(item.issue_id)) continue;
      if (this.hydrationInFlight.has(item.issue_id)) continue;
      if (seen.has(item.issue_id)) continue;
      seen.add(item.issue_id);
      this.hydrationInFlight.add(item.issue_id);
      try {
        const issue = await api.getIssue(item.issue_id);
        const next = new Map(this.issueCache);
        next.set(item.issue_id, issue);
        this.issueCache = next;
        this.version++;
      } catch (err) {
        console.warn('[inbox] hydrate issue failed', err);
      } finally {
        this.hydrationInFlight.delete(item.issue_id);
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Header({
          title: 'Inbox',
          scheme: this.scheme
        })

        if (this._isLoading) {
          this.LoadingState()
        } else if (this._error) {
          this.ErrorState(this._error.message)
        } else if (deduplicateInboxItems(this._data ?? []).length === 0) {
          this.EmptyState()
        } else {
          this.List(deduplicateInboxItems(this._data ?? []))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(themeTokens(this.scheme).background))
      .onClick(() => {
        if (this.menuVisible) this.menuVisible = false;
      })

      if (this.menuVisible) {
        this.MenuSheet()
      }
    }
    .id(`InboxPage-v${this.version}`)
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder FloatingMenuButton() {
    Column() {
      Blank().layoutWeight(1)
      Row() {
        Blank()
        IconButton({
          glyph: '⋯',
          scheme: this.scheme,
          accessibilityLabel: 'Inbox actions',
          onTap: () => { this.menuVisible = !this.menuVisible; }
        })
      }
      .width('100%')
      .padding({ left: space('4'), right: space('4'), bottom: space('3') })
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.Transparent)
  }

  @Builder MenuSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000022')
        .onClick(() => { this.menuVisible = false; })

      Column() {
        this.MenuAction('Mark all read', false, () => { void this.runMenuAction(() => markAllInboxRead()); })
        this.MenuAction('Archive all read', false, () => { void this.runMenuAction(() => archiveAllReadInbox()); })
        this.MenuAction('Archive completed', false, () => { void this.runMenuAction(() => archiveCompletedInbox()); })
        this.MenuAction('Archive all', true, () => { void this.runMenuAction(() => archiveAllInbox()); })
        this.MenuAction('Cancel', false, () => { this.menuVisible = false; })
      }
      .width('100%')
      .padding({ left: space('3'), right: space('3'), bottom: space('3') })
    }
    .width('100%')
    .height('100%')
  }

  @Builder MenuAction(label: string, destructive: boolean, onTap: () => void) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'base',
        weight: 'medium',
        color: destructive ? 'destructive' : 'foreground',
        textAlign: 'center'
      })
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .borderRadius(14)
    .margin({ top: space('2') })
    .justifyContent(FlexAlign.Center)
    .onClick(() => { if (!this.menuBusy) onTap(); })
    .opacity(this.menuBusy ? 0.6 : 1)
  }

  @Builder LoadingState() {
    Column() {
      ForEach([1, 2, 3, 4, 5, 6], (i: number) => {
        Row() {
          Skeleton({ scheme: this.scheme, skeletonWidth: 36, skeletonHeight: 36, radius: 18 })
          Column() {
            Skeleton({ scheme: this.scheme, skeletonWidth: '70%', skeletonHeight: 14, radius: 4 })
            Skeleton({ scheme: this.scheme, skeletonWidth: '40%', skeletonHeight: 12, radius: 4 })
              .margin({ top: space('1.5') })
          }
          .layoutWeight(1)
          .margin({ left: space('3') })
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
      })
    }
  }

  @Builder ErrorState(message: string) {
    Column() {
      MulticaText({
        value: `Failed to load inbox: ${message}`,
        scheme: this.scheme,
        textSize: 'sm',
        color: 'destructive'
      })
        .padding(space('4'))
    }
  }

  @Builder EmptyState() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: 'Inbox zero',
          scheme: this.scheme,
          textSize: 'base',
          weight: 'medium',
          color: 'foreground',
          textAlign: 'center'
        })
        MulticaText({
          value: 'When someone @mentions you, assigns an issue, or an agent finishes a task, it shows up here.',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'mutedForeground',
          textAlign: 'center'
        })
          .margin({ top: space('2') })
          .padding({ left: space('6'), right: space('6') })
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder List(items: InboxItem[]) {
    List({ space: 0 }) {
      ForEach(items, (item: InboxItem) => {
        ListItem() {
          InboxRow({
            item: item,
            scheme: this.scheme,
            issueIdentifier: item.issue_id ? this.issueCache.get(item.issue_id)?.identifier ?? '' : '',
            issueTitle: item.issue_id ? this.issueCache.get(item.issue_id)?.title ?? '' : '',
            onPress: () => { this.onPressItem(item); }
          })
        }
      })
    }
    .layoutWeight(1)
    .width('100%')
    .listDirection(Axis.Vertical)
    .scrollBar(BarState.Off)
  }

  private onPressItem(item: InboxItem): void {
    if (!item.read) {
      void markInboxRead(item.id);
    }
    if (item.issue_id) {
      appNavigation.pushName('IssueDetailPage', navParam('id', item.issue_id));
    }
  }

  private async runMenuAction(action: () => Promise<void>): Promise<void> {
    this.menuBusy = true;
    try {
      await action();
      this.syncFromCache();
      this.menuVisible = false;
    } finally {
      this.menuBusy = false;
    }
  }

  private async archiveItem(itemId: string): Promise<void> {
    this.swipingItemId = '';
    await archiveInboxItem(itemId);
    this.syncFromCache();
  }
}
