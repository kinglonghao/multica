import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { issueDetailKey } from '../queries/issue';
import { updateIssue } from '../mutations/issue';
import { Issue, IssueStatus } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { statusLabel, statusColor } from '../lib/issue-status';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaText } from '../components/ui/Text';
import { PickerRow } from '../components/issue/PickerRow';

/**
 * Issue status picker. Pushed on the navigation stack from the
 * issue detail page when the user taps the status chip —
 * replaces the v0.1 click-cycle placeholder. The new chip-tap
 * flow goes through here:
 *
 *   - Reads the issue from the cache (already populated by
 *     `IssueDetailPage`).
 *   - Renders a single-select list of all status values.
 *   - On selection, calls `updateIssue` (the optimistic mutation
 *     from `mutations/issue.ets`) and pops back to the detail
 *     page. The optimistic patch + server reconcile is handled
 *     inside the mutation; this page only owns the selection
 *     UI.
 *
 * No `onChange` callback to a parent — the page mutates and
 * closes, the detail page reads the cache on its next render.
 * Mirrors the iOS formSheet pattern (issue/[id]/picker/status.tsx).
 */

const STATUSES: IssueStatus[] = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];

@ComponentV2
export struct IssueStatusPickerPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local busy: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private currentValue(): IssueStatus {
    const key = issueDetailKey(workspaceStore.currentId, this.id);
    const issue = queryClient.get<Issue>(key)?.data;
    return (issue?.status as IssueStatus) ?? 'todo';
  }

  private async pick(next: IssueStatus): Promise<void> {
    if (this.busy) return;
    const cur = this.currentValue();
    if (cur === next) {
      appNavigation.pop();
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateIssue(this.id, { status: next });
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to update status';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Status',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (this.errorMsg) {
        MulticaText({
          value: this.errorMsg,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
          .width('100%')
      }

      Scroll() {
        Column() {
          const cur = this.currentValue();
          ForEach(STATUSES, (s: IssueStatus) => {
            PickerRow({
              label: statusLabel(s),
              selected: s === cur,
              scheme: this.scheme,
              leadingIcon: this.StatusDot(s),
              onTap: (): void => { void this.pick(s); }
            })
          })
        }
        .width('100%')
        .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['2'], bottom: SPACE['4'] })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder StatusDot(s: IssueStatus) {
    Row() {
      Blank()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(statusColor(s, this.scheme))
    }
    .width(10)
    .height(10)
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
