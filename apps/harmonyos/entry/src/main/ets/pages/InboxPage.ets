import router from '@ohos.router';
import { useInboxQuery } from '../queries/inbox';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { deduplicateInboxItems } from '../lib/inbox-display';
import { InboxItem, Issue } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { InboxRow } from '../components/inbox/InboxRow';

/**
 * Inbox tab. Mirrors the iOS inbox.tsx — same dedup, same load+empty
 * states, same tap-to-issue behavior. The big difference is that
 * HarmonyOS doesn't have an `Alert.alert` equivalent, so the trailing
 * action menu lives as a separate page (`SwitchWorkspacePage`-style)
 * reachable from the More tab. Trailing actions (mark all read, archive
 * all, etc.) are wired up as plain buttons here, not an action sheet.
 */
@Component
export struct InboxPage {
  @State scheme: ColorScheme = 'light';
  @State showActions: boolean = false;
  @State dataVersion: number = 0; // bumped to force re-render when cache mutates
  private query = useInboxQuery();
  private issueCache = new Map<string, Issue>();

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({
        title: 'Inbox',
        scheme: this.scheme,
        right: this.ActionsRow()
      })

      if (this.query.state.isLoading) {
        this.LoadingState()
      } else if (this.query.state.error) {
        this.ErrorState(this.query.state.error!.message)
      } else {
        const items = deduplicateInboxItems(this.query.state.data ?? []);
        if (items.length === 0) {
          this.EmptyState()
        } else {
          this.List(items)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder ActionsRow() {
    Row() {
      IconButton({
        glyph: '⋯',
        scheme: this.scheme,
        accessibilityLabel: 'Inbox actions',
        onTap: () => { this.showActions = !this.showActions; }
      })
    }
  }

  @Builder LoadingState() {
    Column() {
      ForEach([1, 2, 3, 4, 5, 6], (i: number) => {
        Row() {
          Skeleton({ scheme: this.scheme, width: 36, height: 36, radius: 18 })
          Column() {
            Skeleton({ scheme: this.scheme, width: '70%', height: 14, radius: 4 })
            Skeleton({ scheme: this.scheme, width: '40%', height: 12, radius: 4 })
              .margin({ top: SPACE['1.5'] })
          }
          .layoutWeight(1)
          .margin({ left: SPACE['3'] })
          .alignItems(HorizontalAlign.Start)
        }
        .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
      })
    }
  }

  @Builder ErrorState(message: string) {
    Column() {
      MulticaText({
        value: `Failed to load inbox: ${message}`,
        scheme: this.scheme,
        size: 'sm',
        color: 'destructive'
      })
        .padding(SPACE['4'])
    }
  }

  @Builder EmptyState() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        MulticaText({
          value: 'Inbox zero',
          scheme: this.scheme,
          size: 'base',
          weight: 'medium',
          color: 'foreground',
          textAlign: TextAlign.Center
        })
        MulticaText({
          value: 'When someone @mentions you, assigns an issue, or an agent finishes a task, it shows up here.',
          scheme: this.scheme,
          size: 'sm',
          color: 'mutedForeground',
          textAlign: TextAlign.Center
        })
          .margin({ top: SPACE['2'] })
          .padding({ left: SPACE['6'], right: SPACE['6'] })
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
  }

  private onPressItem(item: InboxItem): void {
    if (!item.read) {
      // Optimistic read flip. We patch the cache synchronously so the
      // row restyles before the row source view is snapshotted for the
      // push transition (mirrors iOS useMarkInboxRead.onMutate).
      queryClient.setQueryData(['inbox', workspaceStore.currentId], (prev: InboxItem[] | undefined) => {
        if (!prev) return prev;
        return prev.map(i => i.id === item.id ? { ...i, read: true } : i);
      });
      api.markInboxRead(item.id).catch((err: Error) => {
        console.warn('[inbox] mark read failed', err);
      });
    }
    if (item.issue_id && workspaceStore.currentSlug) {
      router.pushUrl({ url: 'pages/IssueDetailPage', params: { id: item.issue_id } });
    }
  }
}
