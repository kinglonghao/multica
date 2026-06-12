import { appNavigation } from '../data/navigation';
import { useIssueRunsQuery, QueryHandle } from '../queries/agent-tasks';
import { useTaskRealtime } from '../realtime/realtime-hooks';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { formatElapsedMs, failureReasonLabel, truncate, formatCostUsd } from '../lib/format-utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Card } from '../components/ui/Card';
import { Skeleton } from '../components/ui/Skeleton';
import { AgentTask } from '../models/types';

/**
 * Issue "Runs" tab — the agent tasks spawned by actions on the
 * issue. Pushed from the issue detail page; reads the runs
 * cache (`useIssueRunsQuery`) and subscribes to `task:*` WS
 * events to patch the rows in place.
 *
 * Mirrors `apps/mobile/app/(app)/[workspace]/issues/[id]/runs.tsx`
 * (the iOS runs sub-page). Status / cost / duration come from
 * the `AgentTask` row; we sort by `started_at` desc so the live
 * row is at the top.
 *
 * Empty state: when the server has no runs (or the older
 * `/api/issues/:id/runs` endpoint is missing), the page shows a
 * friendly message instead of a half-populated list. The empty
 * list is also what `useIssueRunsQuery` returns on a 404 (see
 * the catch in `api.listIssueRuns`), so the page renders the
 * "No agent runs yet" copy on a clean install.
 */

const STATUS_LABEL: Record<string, string> = {
  pending: 'Queued',
  running: 'Running',
  completed: 'Completed',
  failed: 'Failed',
  cancelled: 'Cancelled'
};

@ComponentV2
export struct IssueRunsPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  private query: QueryHandle<AgentTask[]> | null = null;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useIssueRunsQuery(this.id, () => { this.version++; });
    // Subscribe to the per-issue task stream so the row list
    // patches in place when a new run starts / completes.
    this.wsUnsub = useTaskRealtime({ issueId: this.id });
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({
        title: 'Agent runs',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (!this.id) {
        MulticaText({
          value: 'No issue id provided',
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
      } else {
        this.Body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }

  @Builder Body() {
    if (!this.query) {
      Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
        .padding(SPACE['4'])
      return;
    }
    const state = this.query.getState();
    Scroll() {
      Column() {
        if (state.isLoading && (!state.data || state.data.length === 0)) {
          ForEach([1, 2, 3], () => {
            Skeleton({ scheme: this.scheme, width: '100%', height: 72, radius: 8 })
              .margin({ top: SPACE['2'] })
          })
        } else if (state.error) {
          MulticaText({
            value: `Failed to load runs: ${state.error?.message ?? ''}`,
            scheme: this.scheme,
            size: 'sm',
            color: 'destructive'
          })
            .padding(SPACE['4'])
            .width('100%')
        } else if (state.data && state.data.length > 0) {
          // Sort by started_at desc — most recent first. The
          // realtime patch already prepends, but a page that
          // loaded from disk may have an unsorted snapshot.
          const sorted = [...state.data].sort((a, b) => {
            const aT = a.started_at ? Date.parse(a.started_at) : 0;
            const bT = b.started_at ? Date.parse(b.started_at) : 0;
            return bT - aT;
          });
          ForEach(sorted, (task: AgentTask) => {
            this.RunRow(task)
          })
        } else {
          this.EmptyState()
        }
      }
      .width('100%')
      .padding(SPACE['4'])
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder RunRow(task: AgentTask) {
    Card({ scheme: this.scheme, padding: SPACE['3'], gap: SPACE['2'] }) {
      Row() {
        // Status pill — text-only on v1, the iconography is
        // a follow-up. The accent color comes from the theme's
        // statusForeground map.
        Row() {
          MulticaText({
            value: STATUS_LABEL[task.status] ?? task.status,
            scheme: this.scheme,
            size: 'xs',
            color: 'foreground',
            weight: 'medium'
          })
        }
        .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['1'], bottom: SPACE['1'] })
        .backgroundColor(String(THEME[this.scheme].card))
        .borderRadius(RADIUS.full)
        Blank()
        if (task.duration_ms !== null && task.duration_ms !== undefined) {
          MulticaText({
            value: formatElapsedMs(task.duration_ms),
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
        }
      }
      .width('100%')

      MulticaText({
        value: truncate(task.prompt, 140),
        scheme: this.scheme,
        size: 'sm',
        color: 'foreground'
      })
        .width('100%')

      Row() {
        MulticaText({
          value: `Started ${timeAgo(task.started_at)}`,
          scheme: this.scheme,
          size: 'xs',
          color: 'mutedForeground'
        })
        const cost = formatCostUsd(task.cost_usd ?? null);
        if (cost) {
          Blank()
          MulticaText({
            value: cost,
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground',
            weight: 'medium'
          })
        }
      }
      .width('100%')

      if (task.status === 'failed' && task.failure_reason) {
        MulticaText({
          value: failureReasonLabel(task.failure_reason),
          scheme: this.scheme,
          size: 'xs',
          color: 'destructive'
        })
          .margin({ top: SPACE['1'] })
      }
    }
    .margin({ top: SPACE['2'] })
    .width('100%')
  }

  @Builder EmptyState() {
    Column() {
      MulticaText({
        value: 'No agent runs yet',
        scheme: this.scheme,
        size: 'md',
        weight: 'semibold',
        color: 'foreground'
      })
        .width('100%')
      MulticaText({
        value: 'Assign this issue to an agent to see its runs here.',
        scheme: this.scheme,
        size: 'sm',
        color: 'mutedForeground'
      })
        .margin({ top: SPACE['2'] })
        .width('100%')
    }
    .padding(SPACE['6'])
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
