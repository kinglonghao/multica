import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { projectDetailKey } from '../queries/project';
import { updateProject } from '../mutations/project';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { Project, UpdateProjectRequest } from '../models/types';

/**
 * Project edit page — pushed from the project detail header.
 * Mirrors the shape of the iOS `apps/mobile/app/(app)/[workspace]/
 * projects/[id]/edit.tsx`. Lets the user edit the project's
 * name, description, status, priority, and lead.
 *
 * Status / priority / lead live on dedicated pickers (the
 * project-status / project-priority / project-lead picker
 * pages) — this form is for the long-form fields. Tapping the
 * status / priority / lead pill pushes the picker, which
 * mutates the project-detail cache directly; this page
 * re-reads the cache on `aboutToAppear` so the pill reflects
 * the new value when the user pops back.
 */
@ComponentV2
export struct ProjectEditPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local name: string = '';
  @Local description: string = '';
  @Local busy: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const key = projectDetailKey(workspaceStore.currentId, this.id);
    const project = queryClient.get<Project>(key)?.data;
    if (project) {
      this.name = project.name;
      this.description = project.description ?? '';
    }
  }

  aboutToDisappear(): void { /* noop */ }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    const name = this.name.trim();
    if (!name) {
      this.errorMsg = 'Name is required';
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    const req: UpdateProjectRequest = {};
    const key = projectDetailKey(workspaceStore.currentId, this.id);
    const prev = queryClient.get<Project>(key)?.data;
    if (prev && name !== prev.name) req.name = name;
    if (prev && this.description !== (prev.description ?? '')) req.description = this.description;
    if (Object.keys(req).length === 0) {
      appNavigation.pop();
      return;
    }
    try {
      await updateProject(this.id, req);
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to save project';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Edit project',
        scheme: this.scheme,
        left: this.CancelButton()
      })

      Scroll() {
        Column() {
          if (this.errorMsg) {
            MulticaText({
              value: this.errorMsg,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .margin({ bottom: SPACE['3'] })
              .width('100%')
          }

          MulticaText({
            value: 'Name',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .width('100%')
          TextInput({ text: this.name, placeholder: 'Project name' })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.name = value; })

          MulticaText({
            value: 'Description',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['4'] })
            .width('100%')
          TextArea({ text: this.description, placeholder: 'Add a description…' })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .height(120)
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.description = value; })

          MulticaButton({
            label: this.busy ? 'Saving…' : 'Save changes',
            scheme: this.scheme,
            variant: 'primary',
            disabled: this.busy || this.name.trim().length === 0,
            onTap: () => { void this.save(); }
          })
            .margin({ top: SPACE['6'] })
        }
        .width('100%')
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

  @Builder CancelButton() {
    IconButton({
      glyph: '✕',
      scheme: this.scheme,
      accessibilityLabel: 'Cancel',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
