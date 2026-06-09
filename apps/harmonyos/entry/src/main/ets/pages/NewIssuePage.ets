import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import { api } from '../data/api';
import { CreateIssueRequest, IssueStatus, IssuePriority } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { StatusIcon } from '../components/ui/StatusIcon';
import { PriorityIcon } from '../components/ui/PriorityIcon';

@Entry
@Component
struct NewIssuePage {
  @State scheme: ColorScheme = 'light';
  @State title: string = '';
  @State description: string = '';
  @State status: IssueStatus = 'todo';
  @State priority: IssuePriority = 'no_priority';
  @State saving: boolean = false;
  @State errorMessage: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async submit(): Promise<void> {
    if (this.title.trim().length === 0) {
      this.errorMessage = 'Title is required';
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
      const issue = await api.createIssue(req);
      router.replaceUrl({ url: 'pages/IssueDetailPage', params: { id: issue.id } });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Failed to create issue';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'New issue',
        scheme: this.scheme,
        left: this.CancelButton(),
        right: this.SubmitButton()
      })

      Scroll() {
        Column() {
          MulticaText({
            value: 'Title',
            scheme: this.scheme,
            size: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
            .margin({ top: SPACE['4'] })

          TextInput({ placeholder: 'What needs to be done?', text: this.title })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['2'] })
            .onChange((value: string) => {
              this.title = value;
              this.errorMessage = '';
            })

          MulticaText({
            value: 'Description',
            scheme: this.scheme,
            size: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
            .margin({ top: SPACE['4'] })

          TextArea({ placeholder: 'Add more context (optional)', text: this.description })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .height(120)
            .margin({ top: SPACE['2'] })
            .onChange((value: string) => {
              this.description = value;
            })

          this.PickerRow('Status', statusLabel(this.status), () => this.cycleStatus())
          this.PickerRow('Priority', priorityLabel(this.priority), () => this.cyclePriority())

          if (this.errorMessage) {
            MulticaText({
              value: this.errorMessage,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .margin({ top: SPACE['2'] })
          }
        }
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

  @Builder PickerRow(label: string, value: string, onTap: () => void) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        size: 'sm',
        weight: 'medium',
        color: 'foreground'
      })
      Blank()
      MulticaText({
        value: value,
        scheme: this.scheme,
        size: 'sm',
        color: 'mutedForeground'
      })
      MulticaText({
        value: ' ›',
        scheme: this.scheme,
        size: 'sm',
        color: 'mutedForeground'
      })
    }
    .width('100%')
    .padding({ left: SPACE['3'], right: SPACE['3'], top: SPACE['3'], bottom: SPACE['3'] })
    .backgroundColor(String(THEME[this.scheme].card))
    .borderRadius(RADIUS.md)
    .margin({ top: SPACE['3'] })
    .onClick(() => { onTap(); })
  }

  @Builder CancelButton() {
    IconButton({
      glyph: '×',
      scheme: this.scheme,
      accessibilityLabel: 'Cancel',
      onTap: () => { router.back(); }
    })
  }

  @Builder SubmitButton() {
    MulticaButton({
      label: this.saving ? 'Saving…' : 'Create',
      scheme: this.scheme,
      variant: 'primary',
      size: 'sm',
      disabled: this.saving,
      onTap: () => { void this.submit(); }
    })
  }

  private cycleStatus(): void {
    const order: IssueStatus[] = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];
    const idx = order.indexOf(this.status);
    this.status = order[(idx + 1) % order.length];
  }

  private cyclePriority(): void {
    const order: IssuePriority[] = ['no_priority', 'low', 'medium', 'high', 'urgent'];
    const idx = order.indexOf(this.priority);
    this.priority = order[(idx + 1) % order.length];
  }
}
