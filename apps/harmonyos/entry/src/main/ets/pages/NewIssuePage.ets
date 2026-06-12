import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { CreateIssueRequest, IssueStatus, IssuePriority } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { themeController } from '../lib/theme-controller';
import { localeController, t } from '../lib/locale';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { Preferences } from '../data/preferences';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { StatusIcon } from '../components/ui/StatusIcon';
import { PriorityIcon } from '../components/ui/PriorityIcon';
import { MessageComposer } from '../components/composer/MessageComposer';
import { MarkdownToolbar } from '../components/editor/MarkdownToolbar';

interface DraftShape {
  title: string;
  description: string;
  status: IssueStatus;
  priority: IssuePriority;
  mentions: string[];
  attachmentCount: number;
}

/**
 * New issue form. Backed by the shared `Preferences` snapshot
 * for a per-device draft so a kill-and-relaunch doesn't lose
 * the in-flight text. The full feature parity with the iOS
 * client (rich editor + attachment picker) is gated on
 * H4/H5; for M4 we ship the form fields, mention chips, and
 * a draft save indicator.
 */
@ComponentV2
export struct NewIssuePage {
  @Local scheme: ColorScheme = 'light';
  @Local title: string = '';
  @Local description: string = '';
  @Local status: IssueStatus = 'todo';
  @Local priority: IssuePriority = 'no_priority';
  @Local mentions: string[] = [];
  @Local attachmentCount: number = 0;
  @Local saving: boolean = false;
  @Local errorMessage: string = '';
  @Local draftSaved: boolean = false;
  @Local localeVersion: number = 0;
  private themeUnsub?: () => void;
  private localeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.localeUnsub = localeController.subscribe(() => { this.localeVersion++; });
    void this.restoreDraft();
  }

  aboutToDisappear(): void {
    this.themeUnsub?.();
    this.localeUnsub?.();
  }

  private async restoreDraft(): Promise<void> {
    const raw = await Preferences.getNewIssueDraft();
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw) as Partial<DraftShape>;
      this.title = parsed.title ?? '';
      this.description = parsed.description ?? '';
      this.status = (parsed.status as IssueStatus) ?? 'todo';
      this.priority = (parsed.priority as IssuePriority) ?? 'no_priority';
      this.mentions = Array.isArray(parsed.mentions) ? parsed.mentions : [];
      this.attachmentCount = typeof parsed.attachmentCount === 'number' ? parsed.attachmentCount : 0;
    } catch {
      // Stale / corrupt draft; ignore and start fresh.
    }
  }

  private async persistDraft(): Promise<void> {
    const draft: DraftShape = {
      title: this.title,
      description: this.description,
      status: this.status,
      priority: this.priority,
      mentions: this.mentions,
      attachmentCount: this.attachmentCount
    };
    await Preferences.setNewIssueDraft(JSON.stringify(draft));
    this.draftSaved = true;
  }

  private async clearDraft(): Promise<void> {
    await Preferences.setNewIssueDraft('');
    this.draftSaved = false;
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
      // Bug 8 fix (v0.3): invalidate every issue-list query key so
      // the newly-created issue shows up in MyIssuesPage / search
      // / project lists. The cache module exposes a wildcard-free
      // invalidate — we walk the registered keys for the current
      // workspace and drop every key whose first segment is
      // 'issues'.
      queryClient.invalidatePrefix(['issues', workspaceStore.currentId]);
      await this.clearDraft();
      appNavigation.pushName('IssueDetailPage', { id: issue.id });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : t('new_issue_failed');
    } finally {
      this.saving = false;
    }
  }

  /**
   * Insert markdown around the current description. We keep a
   * simple "append" behavior because the TextArea doesn't expose
   * cursor positions to ArkTS V2. For M4 this is good enough;
   * a future revision can plumb the cursor via `controller.caretOffset`.
   */
  private applyMarkdownAction(key: 'bold' | 'italic' | 'code' | 'link' | 'list' | 'quote' | 'heading' | 'attach'): void {
    switch (key) {
      case 'bold': this.description = `${this.description} **bold**`; break;
      case 'italic': this.description = `${this.description} _italic_`; break;
      case 'code': this.description = `${this.description} \`code\``; break;
      case 'link': this.description = `${this.description} [text](url)`; break;
      case 'list': this.description = `${this.description}\n- item`; break;
      case 'quote': this.description = `${this.description}\n> quote`; break;
      case 'heading': this.description = `${this.description}\n## heading`; break;
      case 'attach':
        // M4: increment the local counter. The real picker (H4)
        // will pop a system file picker and stash real upload
        // refs. Until then the count is purely UI.
        this.attachmentCount = this.attachmentCount + 1;
        break;
    }
    void this.persistDraft();
  }

  build() {
    Column() {
      Header({
        title: t('new_issue_title'),
        scheme: this.scheme,
        left: this.CancelButton(),
        right: this.SubmitButton()
      })

      Scroll() {
        Column() {
          MulticaText({
            value: t('new_issue_title_placeholder'),
            scheme: this.scheme,
            size: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
            .margin({ top: SPACE['4'] })

          MessageComposer({
            value: this.title,
            scheme: this.scheme,
            placeholder: 'What needs to be done?',
            onChange: (v: string) => {
              this.title = v;
              this.errorMessage = '';
              void this.persistDraft();
            }
          })
            .margin({ top: SPACE['2'] })

          MulticaText({
            value: t('new_issue_description_placeholder'),
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
            .height(160)
            .margin({ top: SPACE['2'] })
            .onChange((value: string) => {
              this.description = value;
              void this.persistDraft();
            })

          MarkdownToolbar({
            scheme: this.scheme,
            onAction: (k) => { this.applyMarkdownAction(k); }
          })

          // Mentions row — a chip per currently-mentioned user.
          if (this.mentions.length > 0) {
            MulticaText({
              value: 'Mentions',
              scheme: this.scheme,
              size: 'xs',
              weight: 'semibold',
              color: 'mutedForeground'
            })
              .margin({ top: SPACE['4'] })
            Row() {
              ForEach(this.mentions, (m: string) => {
                this.MentionChip(m)
              })
            }
            .margin({ top: SPACE['2'] })
          } else {
            MulticaText({
              value: 'Tip: type @ to mention a teammate',
              scheme: this.scheme,
              size: 'xs',
              color: 'mutedForeground'
            })
              .margin({ top: SPACE['2'] })
          }

          // Attachments row
          if (this.attachmentCount > 0) {
            MulticaText({
              value: `${t('new_issue_attach')} (${this.attachmentCount})`,
              scheme: this.scheme,
              size: 'xs',
              weight: 'semibold',
              color: 'mutedForeground'
            })
              .margin({ top: SPACE['4'] })
            Row() {
              ForEach([0, 1, 2], () => {
                Stack() { MulticaText({ value: '📎', scheme: this.scheme, size: 'lg' }) }
                  .width(56)
                  .height(56)
                  .borderRadius(RADIUS.md)
                  .backgroundColor(String(THEME[this.scheme].card))
                  .margin({ right: SPACE['2'] })
                  .alignItems(VerticalAlign.Center)
                  .justifyContent(FlexAlign.Center)
              })
            }
            .margin({ top: SPACE['2'] })
          }

          this.PickerRow('status', 'Status', statusLabel(this.status))
          this.PickerRow('priority', 'Priority', priorityLabel(this.priority))

          if (this.draftSaved) {
            MulticaText({
              value: t('new_issue_draft_saved'),
              scheme: this.scheme,
              size: 'xs',
              color: 'success'
            })
              .margin({ top: SPACE['2'] })
          }

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

  @Builder MentionChip(handle: string) {
    Row() {
      MulticaText({
        value: `@${handle}`,
        scheme: this.scheme,
        size: 'xs',
        weight: 'medium',
        color: 'brand'
      })
      MulticaText({
        value: ' ×',
        scheme: this.scheme,
        size: 'xs',
        color: 'mutedForeground'
      })
    }
    .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['1'], bottom: SPACE['1'] })
    .borderRadius(RADIUS.full)
    .backgroundColor(String(THEME[this.scheme].card))
    .margin({ right: SPACE['1'] })
  }

  @Builder PickerRow(kind: 'status' | 'priority', label: string, value: string) {
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
    .onClick(() => {
      // Bug 10 fix: dispatch on the typed `kind` param, not the
      // human-readable label. The label is a future i18n concern;
      // a string compare would silently break under a non-English
      // build. The `kind` union is compile-time fixed.
      if (kind === 'status') {
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
      accessibilityLabel: t('common_cancel'),
      onTap: () => { appNavigation.pop(); }
    })
  }

  @Builder SubmitButton() {
    MulticaButton({
      label: this.saving ? '…' : t('new_issue_submit'),
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
    void this.persistDraft();
  }

  private cyclePriority(): void {
    const order: IssuePriority[] = ['no_priority', 'low', 'medium', 'high', 'urgent'];
    const idx = order.indexOf(this.priority);
    this.priority = order[(idx + 1) % order.length];
    void this.persistDraft();
  }
}
