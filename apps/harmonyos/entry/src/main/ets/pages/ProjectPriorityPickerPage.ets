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
import { Project, ProjectPriority } from '../models/types';
import { projectPriorityLabel } from '../lib/project-status';

/**
 * Project priority picker. Same shape as the project-status
 * picker — chip-tap on the project detail page routes here,
 * the optimistic `updateProject` mutation fires on select.
 */

const PROJECT_PRIORITIES: ProjectPriority[] = ['no_priority', 'urgent', 'high', 'medium', 'low'];

@ComponentV2
export struct ProjectPriorityPickerPage {
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

  private currentValue(): ProjectPriority {
    const key = projectDetailKey(workspaceStore.currentId, this.id);
    const project = queryClient.get<Project>(key)?.data;
    return (project?.priority as ProjectPriority) ?? 'no_priority';
  }

  private async pick(next: ProjectPriority): Promise<void> {
    if (this.busy) return;
    const cur = this.currentValue();
    if (cur === next) {
      appNavigation.pop();
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateProject(this.id, { priority: next });
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
          ForEach(PROJECT_PRIORITIES, (p: ProjectPriority) => {
            PickerRow({
              label: projectPriorityLabel(p),
              selected: p === cur,
              scheme: this.scheme,
              onTap: (): void => { void this.pick(p); }
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

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
