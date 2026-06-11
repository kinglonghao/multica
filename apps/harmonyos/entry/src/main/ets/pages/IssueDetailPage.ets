import { appNavigation } from '../data/navigation';
import { useIssueDetailQuery, QueryHandle } from '../queries/issue';
import { useQuery, QueryHandle as QH } from '../queries/cache';
import { useIssueRealtime } from '../realtime/realtime-hooks';
import { api } from '../data/api';
import { createComment, updateComment, deleteComment } from '../mutations/issue';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE, RADIUS, textColor } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { StatusIcon } from '../components/ui/StatusIcon';
import { PriorityIcon } from '../components/ui/PriorityIcon';
import { Avatar } from '../components/ui/Avatar';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { Card } from '../components/ui/Card';
import { Markdown } from '../components/ui/Markdown';
import { Issue, Comment } from '../models/types';

const COMMENTS_KEY = (id: string): readonly (string | number | boolean)[] => ['issue-comments', id];

@ComponentV2
export struct IssueDetailPage {
  @Local id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local commentDraft: string = '';
  @Local sendingComment: boolean = false;
  @Local commentError: string = '';
  @Local editingCommentId: string = '';
  @Local editingDraft: string = '';
  @Local savingEdit: boolean = false;
  private query: QueryHandle<Issue> | null = null;
  private comments: QH<Comment[]> | null = null;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.id = appNavigation.readString('IssueDetailPage', 'id', '');
    this.query = useIssueDetailQuery(this.id, () => { this.version++; });
    this.comments = useQuery<Comment[]>(
      COMMENTS_KEY(this.id),
      ({ signal }) => api.listComments(this.id, { signal }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; } }
    );
    // Subscribe to issue:updated events for this specific issue.
    // The hook also patches the cache for us on each update.
    this.wsUnsub = useIssueRealtime(this.id);
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.comments?.unsubscribe();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async submitComment(): Promise<void> {
    const text = this.commentDraft.trim();
    if (!text || this.sendingComment) return;
    this.sendingComment = true;
    this.commentError = '';
    try {
      await createComment(this.id, text);
      this.commentDraft = '';
      this.comments?.refetch();
    } catch (err) {
      this.commentError = err instanceof Error ? err.message : 'Failed to post comment';
    } finally {
      this.sendingComment = false;
    }
  }

  private startEditing(c: Comment): void {
    this.editingCommentId = c.id;
    this.editingDraft = c.body;
  }

  private cancelEditing(): void {
    this.editingCommentId = '';
    this.editingDraft = '';
  }

  private async saveEdit(): Promise<void> {
    if (!this.editingCommentId || this.savingEdit) return;
    const text = this.editingDraft.trim();
    if (!text) return;
    this.savingEdit = true;
    try {
      await updateComment(this.id, this.editingCommentId, text);
      this.editingCommentId = '';
      this.editingDraft = '';
      this.comments?.refetch();
    } catch (err) {
      console.warn('[issue] edit comment failed', err);
    } finally {
      this.savingEdit = false;
    }
  }

  private async removeComment(c: Comment): Promise<void> {
    try {
      await deleteComment(this.id, c.id);
      this.comments?.refetch();
    } catch (err) {
      console.warn('[issue] delete comment failed', err);
    }
  }

  build() {
    Column() {
      Header({
        title: this.id ? 'Issue' : 'Loading…',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (!this.id) {
        MulticaText({
          value: 'No issue id provided',
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
      } else {
        this.Body()
      }
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

  @Builder Body() {
    if (!this.query) {
      Skeleton({ scheme: this.scheme, width: 80, height: 12, radius: 4 })
      return;
    }
    const state = this.query.getState();
    Scroll() {
      Column() {
        if (state.isLoading) {
          this.Loading()
        } else if (state.error) {
          this.ErrorState(state.error!.message)
        } else if (state.data) {
          this.IssueHeader(state.data)
          this.Timeline()
          this.Composer()
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder IssueHeader(issue: Issue) {
    Column() {
      MulticaText({
        value: issue.identifier,
        scheme: this.scheme,
        size: 'xs',
        color: 'mutedForeground',
        weight: 'medium'
      })
      MulticaText({
        value: issue.title,
        scheme: this.scheme,
        size: 'xl',
        weight: 'bold',
        color: 'foreground'
      })
        .margin({ top: SPACE['2'] })

      Row() {
        this.AttributeChip(issue.status, 'status')
        this.AttributeChip(issue.priority, 'priority')
      }
      .margin({ top: SPACE['3'] })

      if (issue.description) {
        Card({ scheme: this.scheme, padding: SPACE['4'], gap: SPACE['2'] }) {
          Markdown({
            value: issue.description,
            scheme: this.scheme,
            onLinkPress: (url: string): void => { this.openLink(url); }
          })
        }
        .margin({ top: SPACE['4'] })
        .width('100%')
      }

      if (issue.assignee_name) {
        Row() {
          Avatar({ name: issue.assignee_name, url: issue.assignee_avatar_url ?? '', size: 32, scheme: this.scheme })
          MulticaText({
            value: `Assigned to ${issue.assignee_name}`,
            scheme: this.scheme,
            size: 'sm',
            color: 'foreground'
          })
            .margin({ left: SPACE['2'] })
        }
        .margin({ top: SPACE['3'] })
      }

      MulticaText({
        value: `Created ${timeAgo(issue.created_at)} · Updated ${timeAgo(issue.updated_at)}`,
        scheme: this.scheme,
        size: 'xs',
        color: 'mutedForeground'
      })
        .margin({ top: SPACE['3'] })

      MulticaText({
        value: 'Activity',
        scheme: this.scheme,
        size: 'md',
        weight: 'semibold',
        color: 'foreground'
      })
        .margin({ top: SPACE['6'], bottom: SPACE['2'] })
        .width('100%')
    }
    .width('100%')
    .padding(SPACE['4'])
    .alignItems(HorizontalAlign.Start)
  }

  @Builder Timeline() {
    if (!this.comments) {
      return;
    }
    const state = this.comments.getState();
    Column() {
      if (state.isLoading) {
        ForEach([1, 2, 3], () => {
          Skeleton({ scheme: this.scheme, width: '100%', height: 56, radius: 8 })
            .margin({ top: SPACE['2'] })
        })
      } else if (state.data && state.data.length > 0) {
        ForEach(state.data, (c: Comment) => {
          this.CommentRow(c)
        })
      } else {
        MulticaText({
          value: 'No activity yet. Be the first to comment.',
          scheme: this.scheme,
          size: 'sm',
          color: 'mutedForeground'
        })
          .width('100%')
      }
    }
    .width('100%')
    .padding({ left: SPACE['4'], right: SPACE['4'] })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder CommentRow(c: Comment) {
    Row() {
      Avatar({ name: c.author_name ?? '·', url: c.author_avatar_url ?? '', size: 32, scheme: this.scheme })
      Column() {
        Row() {
          MulticaText({
            value: c.author_name ?? 'Unknown',
            scheme: this.scheme,
            size: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
          MulticaText({
            value: ` · ${timeAgo(c.created_at)}`,
            scheme: this.scheme,
            size: 'xs',
            color: 'mutedForeground'
          })
        }
        if (this.editingCommentId === c.id) {
          TextArea({ text: this.editingDraft })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['2'])
            .width('100%')
            .height(80)
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.editingDraft = value; })
          Row() {
            MulticaButton({
              label: this.savingEdit ? 'Saving…' : 'Save',
              scheme: this.scheme, variant: 'primary', size: 'sm',
              disabled: this.savingEdit || this.editingDraft.trim().length === 0,
              onTap: () => { void this.saveEdit(); }
            })
            MulticaButton({
              label: 'Cancel',
              scheme: this.scheme, variant: 'ghost', size: 'sm',
              onTap: () => { this.cancelEditing(); }
            })
              .margin({ left: SPACE['2'] })
          }
          .margin({ top: SPACE['1'] })
        } else {
          MulticaText({
            value: c.body,
            scheme: this.scheme,
            size: 'sm',
            color: 'foreground'
          })
            .margin({ top: SPACE['1'] })
            .width('100%')
          // Edit / delete affordance for the comment's author.
          if (c.author_id === authStore.getState().user?.id) {
            Row() {
              MulticaText({
                value: 'Edit',
                scheme: this.scheme,
                size: 'xs',
                weight: 'medium',
                color: 'brand'
              })
                .onClick(() => { this.startEditing(c); })
              MulticaText({
                value: 'Delete',
                scheme: this.scheme,
                size: 'xs',
                weight: 'medium',
                color: 'destructive'
              })
                .margin({ left: SPACE['4'] })
                .onClick(() => { void this.removeComment(c); })
            }
            .margin({ top: SPACE['1'] })
          }
        }
      }
      .layoutWeight(1)
      .margin({ left: SPACE['2'] })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: SPACE['3'], bottom: SPACE['3'] })
    .border({
      width: { top: 1 },
      color: String(THEME[this.scheme].border)
    })
  }

  @Builder Composer() {
    Column() {
      if (this.commentError) {
        MulticaText({
          value: this.commentError,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .margin({ bottom: SPACE['2'] })
          .width('100%')
      }
      TextArea({ placeholder: 'Write a comment…', text: this.commentDraft })
        .placeholderColor(String(THEME[this.scheme].mutedForeground))
        .fontColor(String(THEME[this.scheme].foreground))
        .backgroundColor(String(THEME[this.scheme].card))
        .borderRadius(RADIUS.md)
        .padding(SPACE['3'])
        .width('100%')
        .height(100)
        .onChange((value: string) => { this.commentDraft = value; })
      MulticaButton({
        label: this.sendingComment ? 'Posting…' : 'Comment',
        scheme: this.scheme,
        variant: 'primary',
        size: 'sm',
        disabled: this.sendingComment || this.commentDraft.trim().length === 0,
        onTap: () => { void this.submitComment(); }
      })
        .margin({ top: SPACE['2'] })
    }
    .width('100%')
    .padding(SPACE['4'])
    .alignItems(HorizontalAlign.End)
  }

  @Builder AttributeChip(value: string, kind: 'status' | 'priority') {
    Row() {
      if (kind === 'status') {
        StatusIcon({ status: value, scheme: this.scheme, size: 12 })
      } else {
        PriorityIcon({ priority: value, scheme: this.scheme, size: 12 })
      }
      MulticaText({
        value: kind === 'status' ? statusLabel(value) : priorityLabel(value),
        scheme: this.scheme,
        size: 'xs',
        color: 'foreground',
        weight: 'medium'
      })
        .margin({ left: SPACE['1.5'] })
    }
    .padding({ left: SPACE['2.5'], right: SPACE['2.5'], top: SPACE['1.5'], bottom: SPACE['1.5'] })
    .backgroundColor(String(THEME[this.scheme].card))
    .borderRadius(RADIUS.full)
    .margin({ right: SPACE['2'] })
    // M2 (WS-106 H1): tapping the chip opens the dedicated
    // picker page instead of cycling through values. The
    // picker page runs the optimistic updateIssue mutation
    // and pops back; the chip re-renders with the new value
    // when the page next reads the cache.
    .onClick(() => { this.openAttributePicker(kind); })
  }

  /**
   * Open the dedicated picker page for the attribute. The
   * picker is a Navigation destination, not a sheet — the
   * HarmonyOS app uses a page stack (formSheet presentation
   * isn't a first-class pattern in the V2 Navigation API the
   * same way it is on iOS UISheetPresentationController).
   * Semantics match the iOS formSheet picker: self-contained
   * page that reads from cache, fires the mutation on select,
   * and pops back to the detail screen.
   */
  private openAttributePicker(kind: 'status' | 'priority'): void {
    if (!this.id) return;
    if (kind === 'status') {
      appNavigation.pushName('IssueStatusPickerPage', { id: this.id });
    } else {
      appNavigation.pushName('IssuePriorityPickerPage', { id: this.id });
    }
  }

  private openLink(url: string): void {
    // Outbound link handling. ArkUI doesn't ship a
    // `Linking.openURL`-style helper; a future port can
    // wire in `@ohos.app.ability.StartAbility` for browser
    // handoff. For now we log the intent — the link is
    // rendered as styled brand-colored text and the user
    // can long-press to copy.
    console.info(`[issue] openLink: ${url}`);
  }

  @Builder Loading() {
    Column() {
      Skeleton({ scheme: this.scheme, width: 80, height: 12, radius: 4 })
      Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
        .margin({ top: SPACE['2'] })
      Skeleton({ scheme: this.scheme, width: '100%', height: 80, radius: 8 })
        .margin({ top: SPACE['4'] })
    }
    .padding(SPACE['4'])
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder ErrorState(message: string) {
    MulticaText({
      value: `Failed to load issue: ${message}`,
      scheme: this.scheme,
      size: 'sm',
      color: 'destructive'
    })
      .padding(SPACE['4'])
  }
}
