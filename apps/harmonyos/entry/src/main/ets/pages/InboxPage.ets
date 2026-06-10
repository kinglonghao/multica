import { appNavigation } from '../data/navigation';
import { useInboxQuery } from '../queries/inbox';
import { useQuery, QueryHandle } from '../queries/cache';
import { useInboxRealtime } from '../realtime/realtime-hooks';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { deduplicateInboxItems } from '../lib/inbox-display';
import { markInboxRead } from '../mutations/inbox';
import { InboxItem, Issue } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Skeleton } from '../components/ui/Skeleton';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { InboxRow } from '../components/inbox/InboxRow';

@ComponentV2
export struct InboxPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local issueCache: Map<string, Issue> = new Map();
  private query: QueryHandle<InboxItem[]> | null = null;
  // Bug 9 fix: hydrateIssueCache can fire from BOTH aboutToAppear
  // and the onUpdate callback. Without this Set, two concurrent
  // invocations both pass the `this.issueCache.has(id)` check
  // (because neither has written yet) and double-fetch the same
  // issue. The Set tracks IDs whose fetch is in flight.
  private hydrationInFlight: Set<string> = new Set();
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useInboxQuery(() => {
      this.version++;
      void this.hydrateIssueCache();
    });
    void this.hydrateIssueCache();
    // Subscribe to inbox:created / inbox:updated / inbox:deleted
    // events for the current workspace. The hook invalidates
    // the inbox list cache so the next subscriber refetches.
    this.wsUnsub = useInboxRealtime();
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  /**
   * H-2: the v0.2 inbox had an empty `issueCache` — rows showed
   * "MUL-123 · <empty title>" because no one ever populated it.
   * The fix: every time the inbox list updates, fan out a getIssue
   * fetch for every distinct issue_id and store the result in
   * the cache. Each getIssue hits the cache key
   * `['issue', wsId, id]` (set up by `useIssueDetailQuery`), so
   * a later visit to the issue detail page reuses the fetched data
   * and the inbox row's title/identifier are populated.
   *
   * v0.4 hardening: bump `version` after every cache write so a
   * page that didn't itself receive the `onUpdate` callback
   * (e.g. a navigated-back instance whose subscription was torn
   * down) still re-renders. Belt and suspenders — `@Local` should
   * already fire on the map reference swap, but the extra bump
   * makes the data flow obvious to the next reader.
   */
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
        // Build a new map (immutable) so the page re-renders.
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
    Column() {
      Header({
        title: 'Inbox',
        scheme: this.scheme,
        right: this.ActionsRow()
      })

      if (!this.query) {
        return this.EmptyState();
      }
      const state = this.query.getState();
      if (state.isLoading) {
        this.LoadingState()
      } else if (state.error) {
        this.ErrorState(state.error!.message)
      } else {
        const items = deduplicateInboxItems(state.data ?? []);
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
        onTap: () => { void this.archiveAllRead(); }
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
      // Bug 7 fix: route through the mutation module, not the raw
      // API. The mutation does the optimistic patch + server call
      // + cache invalidate. Calling api.markInboxRead() directly
      // skipped the invalidate, so the prior server-truth could
      // drift on a future refetch (and the row would flip back to
      // "unread" if the server had a different state than our
      // optimistic patch).
      void markInboxRead(item.id);
    }
    if (item.issue_id) {
      appNavigation.pushName('IssueDetailPage', { id: item.issue_id });
    }
  }

  private async archiveAllRead(): Promise<void> {
    queryClient.setQueryData(['inbox', workspaceStore.currentId], (prev: InboxItem[] | undefined) => {
      if (!prev) return prev;
      return prev.map(i => i.read ? { ...i, archived: true } : i);
    });
    try {
      await api.archiveAllReadInbox();
    } finally {
      queryClient.invalidate(['inbox', workspaceStore.currentId]);
    }
  }
}
