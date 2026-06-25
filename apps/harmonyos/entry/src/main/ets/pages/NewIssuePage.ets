import hilog from '@ohos.hilog';
import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { CreateIssueRequest, IssueStatus, IssuePriority } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';

const NEW_ISSUE_DEBUG_DOMAIN = 0xFF19;
const NEW_ISSUE_DEBUG_TAG = 'NewIssuePage';

@ComponentV2
export struct NewIssuePage {
  @Local scheme: ColorScheme = 'light';
  @Local title: string = '';
  @Local description: string = '';
  @Local status: IssueStatus = 'todo';
  @Local priority: IssuePriority = 'none';
  @Local saving: boolean = false;
  @Local errorMessage: string = '';

  // #region debug-point issue-create-crash
  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(NEW_ISSUE_DEBUG_DOMAIN, NEW_ISSUE_DEBUG_TAG,
      `stage=${stage} titleLen=${this.title.length} issueStatus=${this.status} priority=${this.priority} ${extra}`);
  }

  private debugError(stage: string, err: Object | null = null): void {
    const message = err instanceof Error ? err.message : `${err ?? 'unknown'}`;
    hilog.error(NEW_ISSUE_DEBUG_DOMAIN, NEW_ISSUE_DEBUG_TAG,
      `stage=${stage} error=${message}`);
  }
  // #endregion

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.debugInfo('aboutToAppear');
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private async submit(): Promise<void> {
    this.debugInfo('submit:start', `descriptionLen=${this.description.length}`);
    if (this.title.trim().length === 0) {
      this.errorMessage = 'Title is required';
      this.debugInfo('submit:blocked-empty-title');
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      const req: CreateIssueRequest = {
        title: this.title.trim(),
        description: this.description.trim() || undefined,
        status: this.status,
        priority: this.priority
      };
      this.debugInfo('submit:request-ready', `trimmedTitleLen=${req.title.length}`);
      const issue = await api.createIssue(req);
      this.debugInfo('submit:created', `issueId=${issue.id}`);
      this.invalidateIssueLists();
      this.debugInfo('submit:invalidate-done', `workspace=${workspaceStore.currentId ?? 'null'}`);
      appNavigation.pushName('IssueDetailPage', navParam('id', issue.id));
      this.debugInfo('submit:navigate', `issueId=${issue.id}`);
    } catch (err) {
      this.debugError('submit:catch', err as Object);
      this.errorMessage = err instanceof Error ? err.message : 'Failed to create issue';
    } finally {
      this.saving = false;
      this.debugInfo('submit:finally', `error=${this.errorMessage || 'none'}`);
    }
  }

  private invalidateIssueLists(): void {
    queryClient.invalidatePrefix(['issues', workspaceStore.currentId]);
  }

  build() {
    Column() {
      Header({
        title: 'New issue',
        scheme: this.scheme,
        left: this.CancelButton
      })

      Scroll() {
        Column({ space: space('4') }) {
          TextInput({ placeholder: 'Issue title', text: this.title })
            .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
            .fontColor(String(themeTokens(this.scheme).foreground))
            .backgroundColor('transparent')
            .fontSize(28)
            .fontWeight(FontWeight.Medium)
            .padding({ top: space('2'), bottom: space('2') })
            .width('100%')
            .onChange((value: string) => {
              this.title = value;
              this.errorMessage = '';
            })

          TextArea({ placeholder: 'Add description...', text: this.description })
            .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
            .fontColor(String(themeTokens(this.scheme).foreground))
            .backgroundColor('transparent')
            .fontSize(16)
            .padding({ top: 0, bottom: 0 })
            .width('100%')
            .height(120)
            .onChange((value: string) => {
              this.description = value;
            })

          Column({ space: space('3') }) {
            this.PickerRow('Status', statusLabel(this.status))
            this.PickerRow('Priority', priorityLabel(this.priority))
          }
          .margin({ top: space('2') })

          if (this.errorMessage) {
            MulticaText({
              value: this.errorMessage,
              scheme: this.scheme,
              textSize: 'sm',
              color: 'destructive'
            })
          }

          MulticaButton({
            label: this.saving ? 'Saving…' : 'Create',
            scheme: this.scheme,
            variant: 'primary',
            fullWidth: true,
            disabled: this.saving || this.title.trim().length === 0,
            onTap: () => { void this.submit(); }
          })
            .margin({ top: space('2') })
        }
        .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('6') })
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder PickerRow(label: string, value: string) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'base',
        weight: 'medium',
        color: 'foreground'
      })
      Blank()
      MulticaText({
        value: value,
        scheme: this.scheme,
        textSize: 'base',
        color: 'mutedForeground'
      })
      MulticaText({
        value: ' ›',
        scheme: this.scheme,
        textSize: 'base',
        color: 'mutedForeground'
      })
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
    .backgroundColor(String(themeTokens(this.scheme).card))
    .borderRadius(RADIUS.md)
    .onClick(() => {
      if (label === 'Status') {
        this.cycleStatus();
      } else {
        this.cyclePriority();
      }
    })
  }

  @Builder CancelButton() {
    IconButton({
      glyph: '×',
      scheme: this.scheme,
      accessibilityLabel: 'Cancel',
      onTap: () => { appNavigation.pop(); }
    })
  }

  private cycleStatus(): void {
    const order: IssueStatus[] = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];
    const idx = order.indexOf(this.status);
    this.status = order[(idx + 1) % order.length];
  }

  private cyclePriority(): void {
    const order: IssuePriority[] = ['none', 'low', 'medium', 'high', 'urgent'];
    const idx = order.indexOf(this.priority);
    this.priority = order[(idx + 1) % order.length];
  }
}
