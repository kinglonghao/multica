import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { issueDetailKey } from '../queries/issue';
import { useProjectListQuery } from '../queries/project';
import { updateIssue } from '../mutations/issue';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { PickerRow } from '../components/issue/PickerRow';
import { Issue, Project } from '../models/types';

/**
 * Issue project picker. Pushed from `IssueEditPage` when the
 * user taps the "Project" pill. Lists every project in the
 * workspace; the user picks one (or "No project") and the
 * optimistic `updateIssue` mutation fires.
 */
@ComponentV2
export struct IssueProjectPickerPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local busy: boolean = false;
  @Local errorMsg: string = '';
  private projects: ReturnType<typeof useProjectListQuery> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.projects = useProjectListQuery(() => { this.version++; });
  }

  aboutToDisappear(): void {
    this.projects?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private currentProjectId(): string {
    const key = issueDetailKey(workspaceStore.currentId, this.id);
    const issue = queryClient.get<Issue>(key)?.data;
    return issue?.project_id ?? '';
  }

  private async pick(projectId: string | null): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateIssue(this.id, { project_id: projectId });
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to update project';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Project',
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
        const cur = this.currentProjectId();
        Column() {
          PickerRow({
            label: 'No project',
            selected: !cur,
            scheme: this.scheme,
            onTap: (): void => { void this.pick(null); }
          })
          if (this.projects) {
            const state = this.projects.getState();
            const list: Project[] = state.data?.projects ?? [];
            ForEach(list, (p: Project) => {
              PickerRow({
                label: p.name,
                selected: cur === p.id,
                scheme: this.scheme,
                onTap: (): void => { void this.pick(p.id); }
              })
            })
          }
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
