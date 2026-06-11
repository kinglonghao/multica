import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { issueDetailKey } from '../queries/issue';
import { updateIssue } from '../mutations/issue';
import { Issue, IssuePriority } from '../models/types';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { priorityLabel, priorityColor } from '../lib/issue-status';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaText } from '../components/ui/Text';
import { PickerRow } from '../components/issue/PickerRow';

/**
 * Issue priority picker. Pushed from the issue detail page when
 * the user taps the priority chip. Mirrors IssueStatusPickerPage
 * (same shape, same lifecycle) — both pickers are first-class
 * pages on the navigation stack rather than a click-cycle
 * placeholder.
 */

const PRIORITIES: IssuePriority[] = ['no_priority', 'urgent', 'high', 'medium', 'low'];

@ComponentV2
export struct IssuePriorityPickerPage {
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

  private currentValue(): IssuePriority {
    const key = issueDetailKey(workspaceStore.currentId, this.id);
    const issue = queryClient.get<Issue>(key)?.data;
    return (issue?.priority as IssuePriority) ?? 'no_priority';
  }

  private async pick(next: IssuePriority): Promise<void> {
    if (this.busy) return;
    const cur = this.currentValue();
    if (cur === next) {
      appNavigation.pop();
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateIssue(this.id, { priority: next });
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to update priority';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Priority',
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
          ForEach(PRIORITIES, (p: IssuePriority) => {
            PickerRow({
              label: priorityLabel(p),
              selected: p === cur,
              scheme: this.scheme,
              leadingIcon: this.PriorityDot(p),
              onTap: (): void => { void this.pick(p); }
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

  @Builder PriorityDot(p: IssuePriority) {
    Row() {
      Blank()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(priorityColor(p, this.scheme))
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
