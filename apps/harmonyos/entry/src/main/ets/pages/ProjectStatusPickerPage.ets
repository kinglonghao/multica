import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { projectDetailKey } from '../queries/project';
import { updateProject } from '../mutations/project';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { PickerRow } from '../components/issue/PickerRow';
import { Project, ProjectStatus } from '../models/types';
import { projectStatusLabel, projectStatusColor } from '../lib/project-status';

/**
 * Project status picker. Mirrors the issue-status picker shape
 * (IssueStatusPickerPage) — the project chip on the detail
 * page taps through here. Selecting a value fires the
 * optimistic `updateProject` mutation; the pop is the user's
 * confirmation that the change is in.
 */

const PROJECT_STATUSES: ProjectStatus[] = ['planned', 'in_progress', 'paused', 'completed', 'cancelled'];

@ComponentV2
export struct ProjectStatusPickerPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local busy: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  aboutToDisappear(): void { /* noop */ }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private currentValue(): ProjectStatus {
    const key = projectDetailKey(workspaceStore.currentId, this.id);
    const project = queryClient.get<Project>(key)?.data;
    return (project?.status as ProjectStatus) ?? 'planned';
  }

  private async pick(next: ProjectStatus): Promise<void> {
    if (this.busy) return;
    const cur = this.currentValue();
    if (cur === next) {
      appNavigation.pop();
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateProject(this.id, { status: next });
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
          ForEach(PROJECT_STATUSES, (s: ProjectStatus) => {
            PickerRow({
              label: projectStatusLabel(s),
              selected: s === cur,
              scheme: this.scheme,
              leadingIcon: this.StatusDot(s),
              onTap: (): void => { void this.pick(s); }
            })
          })
        }
        .width('100%')
        .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['2'], bottom: SPACE['4'] })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder StatusDot(s: ProjectStatus) {
    Row() {
      Blank()
        .width(10)
        .height(10)
        .borderRadius(5)
        .backgroundColor(projectStatusColor(s, this.scheme))
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
