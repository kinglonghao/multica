import { appNavigation } from '../data/navigation';
import { useIssueDetailQuery, QueryHandle } from '../queries/issue';
import { useProjectListQuery } from '../queries/project';
import { updateIssue } from '../mutations/issue';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { Issue, Project, UpdateIssueRequest } from '../models/types';

/**
 * Issue edit page — pushed from the issue detail header. Lets
 * the user edit the issue's title, description, and project
 * without going through a series of pickers.
 *
 * The assignee change lives on a dedicated picker
 * (`IssueAssigneePickerPage`) — that picker can render agent
 * avatars (purple background, robot icon) without bloating this
 * page with two-column layout. The status / priority pickers
 * stay on their dedicated pages too; the chip-tap pattern from
 * M2 is preserved.
 *
 * Save path:
 *   1. Snapshot the local edits as a partial `UpdateIssueRequest`.
 *   2. Call `updateIssue` (optimistic patch + send + reconcile).
 *   3. Pop back to the issue detail; the cache already has the
 *      new values so the chip / description re-render on the
 *      next read.
 *
 * The page subscribes to the issue-detail query so the
 * `Project` pill re-reads its name from the cache when the
 * project picker (`IssueProjectPickerPage`) writes back. The
 * version counter is bumped by both subscriptions, so the page
 * re-renders on every cache mutation.
 */
@ComponentV2
export struct IssueEditPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local title: string = '';
  @Local description: string = '';
  @Local busy: boolean = false;
  @Local errorMsg: string = '';
  private issue: QueryHandle<Issue> | null = null;
  private projects: QueryHandle<{ projects: Project[]; total: number }> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.issue = useIssueDetailQuery(this.id, () => { this.version++; this.hydrateFromCache(); });
    this.projects = useProjectListQuery(() => { this.version++; this.hydrateFromCache(); });
    this.hydrateFromCache();
  }

  aboutToDisappear(): void {
    this.issue?.unsubscribe();
    this.projects?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  /**
   * Read the current issue + project name from the cache. Called
   * on every cache change so the form stays in sync with the
   * picker's write-back.
   */
  private hydrateFromCache(): void {
    if (!this.issue) return;
    const iState = this.issue.getState();
    const issue = iState.data;
    if (!issue) return;
    this.title = issue.title;
    this.description = issue.description ?? '';
  }

  private projectNameFor(id: string): string {
    if (!this.projects) return id;
    const pState = this.projects.getState();
    const found = pState.data?.projects?.find((p) => p.id === id);
    return found?.name ?? id;
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    const title = this.title.trim();
    if (!title) {
      this.errorMsg = 'Title is required';
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    const req: UpdateIssueRequest = {};
    const cur = this.issue ? this.issue.getState().data : undefined;
    if (cur && title !== cur.title) req.title = title;
    if (cur && this.description !== (cur.description ?? '')) req.description = this.description;
    if (Object.keys(req).length === 0) {
      appNavigation.pop();
      return;
    }
    try {
      await updateIssue(this.id, req);
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to save issue';
    } finally {
      this.busy = false;
    }
  }

  private openProjectPicker(): void {
    appNavigation.pushName('IssueProjectPickerPage', { id: this.id });
  }

  build() {
    Column() {
      Header({
        title: 'Edit issue',
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
            value: 'Title',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .width('100%')
          TextInput({ text: this.title, placeholder: 'Issue title' })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.title = value; })

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

          MulticaText({
            value: 'Project',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['4'] })
            .width('100%')
          const curIssue = this.issue ? this.issue.getState().data : undefined;
          const pid = curIssue?.project_id ?? '';
          Row() {
            MulticaText({
              value: pid ? this.projectNameFor(pid) : 'No project',
              scheme: this.scheme,
              size: 'sm',
              color: 'foreground'
            })
            Blank()
            MulticaText({
              value: 'Change',
              scheme: this.scheme,
              size: 'sm',
              weight: 'medium',
              color: 'brand'
            })
          }
          .padding(SPACE['3'])
          .backgroundColor(String(THEME[this.scheme].card))
          .borderRadius(RADIUS.md)
          .margin({ top: SPACE['1'] })
          .width('100%')
          .onClick(() => { this.openProjectPicker(); })

          MulticaButton({
            label: this.busy ? 'Saving…' : 'Save changes',
            scheme: this.scheme,
            variant: 'primary',
            disabled: this.busy || this.title.trim().length === 0,
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
