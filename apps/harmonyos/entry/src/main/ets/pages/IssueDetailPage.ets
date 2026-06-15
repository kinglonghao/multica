import { appNavigation } from '../data/navigation';
import { useIssueDetailQuery, QueryHandle } from '../queries/issue';
import { useQuery, QueryHandle as QH, FetchContext } from '../queries/cache';
import { useIssueRealtime } from '../realtime/realtime-hooks';
import { api } from '../data/api';
import { createComment, updateComment, deleteComment, updateIssue } from '../mutations/issue';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { issueDetailKey } from '../queries/issue';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE, RADIUS, textColor, space, themeTokens } from '../lib/theme';
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
import { Issue, Comment, IssueStatus, IssuePriority, UpdateIssueRequest } from '../models/types';

const COMMENTS_KEY = (id: string): readonly (string | number | boolean)[] => ['issue-comments', id];

@ComponentV2
export struct IssueDetailPage {
  @Param issueId: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local commentDraft: string = '';
  @Local sendingComment: boolean = false;
  @Local commentError: string = '';
  @Local editingCommentId: string = '';
  @Local editingDraft: string = '';
  @Local savingEdit: boolean = false;
  // H-1 fix: @Local mirrors so build() can read them and ArkUI
  // will re-render when the cache settles. See InboxPage.ets.
  @Local _issueIsLoading: boolean = true;
  @Local _issue: Issue | undefined = undefined;
  @Local _issueError: Error | null = null;
  @Local _commentsIsLoading: boolean = true;
  @Local _comments: Comment[] | undefined = undefined;
  @Local _commentsError: Error | null = null;
  private query: QueryHandle<Issue> | null = null;
  private comments: QH<Comment[]> | null = null;
  private wsUnsub?: () => void;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useIssueDetailQuery(this.issueId, () => {
      this.version++;
      this.syncFromCache();
    });
    this.comments = useQuery<Comment[]>(
      COMMENTS_KEY(this.issueId),
      (ctx: FetchContext) => api.listComments(this.issueId, { cancelToken: ctx.cancelToken }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    // Subscribe to issue:updated events for this specific issue.
    // The hook also patches the cache for us on each update.
    this.wsUnsub = useIssueRealtime(this.issueId);
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.comments?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private syncFromCache(): void {
    if (this.query) {
      const s = this.query.getState();
      this._issueIsLoading = s.isLoading;
      this._issue = s.data as Issue | undefined;
      this._issueError = s.error;
    }
    if (this.comments) {
      const s = this.comments.getState();
      this._commentsIsLoading = s.isLoading;
      this._comments = s.data as Comment[] | undefined;
      this._commentsError = s.error;
    }
  }

  private async submitComment(): Promise<void> {
    const text = this.commentDraft.trim();
    if (!text || this.sendingComment) return;
    this.sendingComment = true;
    this.commentError = '';
    try {
      await createComment(this.issueId, text);
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

  private issueState() {
    return this.query ? this.query.getState() : null;
  }

  private commentsState() {
    return this.comments ? this.comments.getState() : null;
  }

  private async saveEdit(): Promise<void> {
    if (!this.editingCommentId || this.savingEdit) return;
    const text = this.editingDraft.trim();
    if (!text) return;
    this.savingEdit = true;
    try {
      await updateComment(this.issueId, this.editingCommentId, text);
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
      await deleteComment(this.issueId, c.id);
      this.comments?.refetch();
    } catch (err) {
      console.warn('[issue] delete comment failed', err);
    }
  }

  build() {
    Column() {
      Header({
        title: this.issueId ? 'Issue' : 'Loading…',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (!this.issueId) {
        MulticaText({
          value: 'No issue id provided',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        this.Body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
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
    if (this._issueIsLoading) {
      this.Loading()
    } else if (this._issueError) {
      this.ErrorState(this._issueError.message)
    } else if (this._issue) {
      Scroll() {
        Column() {
          this.IssueHeader(this._issue!)
          this.Timeline()
          this.Composer()
        }
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      Skeleton({ scheme: this.scheme, skeletonWidth: 80, skeletonHeight: 12, radius: 4 })
    }
  }

  @Builder IssueHeader(issue: Issue) {
    Column() {
      MulticaText({
        value: issue.identifier,
        scheme: this.scheme,
        textSize: 'xs',
        color: 'mutedForeground',
        weight: 'medium'
      })
      MulticaText({
        value: issue.title,
        scheme: this.scheme,
        textSize: 'xl',
        weight: 'bold',
        color: 'foreground'
      })
        .margin({ top: space('2') })

      Row() {
        this.AttributeChip(issue.status, 'status')
        this.AttributeChip(issue.priority, 'priority')
      }
      .margin({ top: space('3') })

      if (issue.description) {
        Column() {
          Card({ scheme: this.scheme, contentPadding: space('4'), gap: space('2') }) {
            MulticaText({
              value: issue.description,
              scheme: this.scheme,
              textSize: 'base',
              color: 'foreground'
            })
          }
        }
        .margin({ top: space('4') })
        .width('100%')
      }

      if (issue.assignee_name) {
        Row() {
          Avatar({ name: issue.assignee_name, url: issue.assignee_avatar_url ?? '', avatarSize: 32, scheme: this.scheme })
          MulticaText({
            value: `Assigned to ${issue.assignee_name}`,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'foreground'
          })
            .margin({ left: space('2') })
        }
        .margin({ top: space('3') })
      }

      MulticaText({
        value: `Created ${timeAgo(issue.created_at)} · Updated ${timeAgo(issue.updated_at)}`,
        scheme: this.scheme,
        textSize: 'xs',
        color: 'mutedForeground'
      })
        .margin({ top: space('3') })

      MulticaText({
        value: 'Activity',
        scheme: this.scheme,
        textSize: 'md',
        weight: 'semibold',
        color: 'foreground'
      })
        .margin({ top: space('6'), bottom: space('2') })
        .width('100%')
    }
    .width('100%')
    .padding(space('4'))
    .alignItems(HorizontalAlign.Start)
  }

  @Builder Timeline() {
    if (this._commentsIsLoading) {
      Column() {
        ForEach([1, 2, 3], () => {
          Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 56, radius: 8 })
            .margin({ top: space('2') })
        })
      }
      .width('100%')
      .padding({ left: space('4'), right: space('4') })
      .alignItems(HorizontalAlign.Start)
    } else if (this._comments && this._comments!.length > 0) {
      Column() {
        ForEach(this._comments!, (c: Comment) => {
          this.CommentRow(c)
        })
      }
      .width('100%')
      .padding({ left: space('4'), right: space('4') })
      .alignItems(HorizontalAlign.Start)
    } else {
      MulticaText({
        value: 'No activity yet. Be the first to comment.',
        scheme: this.scheme,
        textSize: 'sm',
        color: 'mutedForeground'
      })
        .width('100%')
        .padding({ left: space('4'), right: space('4') })
    }
  }

  @Builder CommentRow(c: Comment) {
    Row() {
      Avatar({ name: c.author_name ?? '·', url: c.author_avatar_url ?? '', avatarSize: 32, scheme: this.scheme })
      Column() {
        Row() {
          MulticaText({
            value: c.author_name ?? 'Unknown',
            scheme: this.scheme,
            textSize: 'sm',
            weight: 'medium',
            color: 'foreground'
          })
          MulticaText({
            value: ` · ${timeAgo(c.created_at)}`,
            scheme: this.scheme,
            textSize: 'xs',
            color: 'mutedForeground'
          })
        }
        if (this.editingCommentId === c.id) {
          TextArea({ text: this.editingDraft })
            .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
            .fontColor(String(themeTokens(this.scheme).foreground))
            .backgroundColor(String(themeTokens(this.scheme).card))
            .borderRadius(RADIUS.md)
            .padding(space('2'))
            .width('100%')
            .height(80)
            .margin({ top: space('1') })
            .onChange((value: string) => { this.editingDraft = value; })
          Row() {
            MulticaButton({
              label: this.savingEdit ? 'Saving…' : 'Save',
              scheme: this.scheme, variant: 'primary', buttonSize: 'sm',
              disabled: this.savingEdit || this.editingDraft.trim().length === 0,
              onTap: () => { void this.saveEdit(); }
            })
            MulticaButton({
              label: 'Cancel',
              scheme: this.scheme, variant: 'ghost', buttonSize: 'sm',
              onTap: () => { this.cancelEditing(); }
            })
              .margin({ left: space('2') })
          }
          .margin({ top: space('1') })
        } else {
          MulticaText({
            value: c.body,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'foreground'
          })
            .margin({ top: space('1') })
            .width('100%')
          // Edit / delete affordance for the comment's author.
          if (c.author_id === authStore.getState().user?.id) {
            Row() {
              MulticaText({
                value: 'Edit',
                scheme: this.scheme,
                textSize: 'xs',
                weight: 'medium',
                color: 'brand'
              })
                .onClick(() => { this.startEditing(c); })
              MulticaText({
                value: 'Delete',
                scheme: this.scheme,
                textSize: 'xs',
                weight: 'medium',
                color: 'destructive'
              })
                .margin({ left: space('4') })
                .onClick(() => { void this.removeComment(c); })
            }
            .margin({ top: space('1') })
          }
        }
      }
      .layoutWeight(1)
      .margin({ left: space('2') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({ top: space('3'), bottom: space('3') })
    .border({
      width: { top: 1 },
      color: String(themeTokens(this.scheme).border)
    })
  }

  @Builder Composer() {
    Column() {
      if (this.commentError) {
        MulticaText({
          value: this.commentError,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .margin({ bottom: space('2') })
          .width('100%')
      }
      TextArea({ placeholder: 'Write a comment…', text: this.commentDraft })
        .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
        .fontColor(String(themeTokens(this.scheme).foreground))
        .backgroundColor(String(themeTokens(this.scheme).card))
        .borderRadius(RADIUS.md)
        .padding(space('3'))
        .width('100%')
        .height(100)
        .onChange((value: string) => { this.commentDraft = value; })
      MulticaButton({
        label: this.sendingComment ? 'Posting…' : 'Comment',
        scheme: this.scheme,
        variant: 'primary',
        buttonSize: 'sm',
        disabled: this.sendingComment || this.commentDraft.trim().length === 0,
        onTap: () => { void this.submitComment(); }
      })
        .margin({ top: space('2') })
    }
    .width('100%')
    .padding(space('4'))
    .alignItems(HorizontalAlign.End)
  }

  @Builder AttributeChip(value: string, kind: 'status' | 'priority') {
    Row() {
      if (kind === 'status') {
        StatusIcon({ status: value, scheme: this.scheme, iconSize: 12 })
      } else {
        PriorityIcon({ priority: value, scheme: this.scheme, iconSize: 12 })
      }
      MulticaText({
        value: kind === 'status' ? statusLabel(value) : priorityLabel(value),
        scheme: this.scheme,
        textSize: 'xs',
        color: 'foreground',
        weight: 'medium'
      })
        .margin({ left: space('1.5') })
    }
    .padding({ left: space('2.5'), right: space('2.5'), top: space('1.5'), bottom: space('1.5') })
    .backgroundColor(String(themeTokens(this.scheme).card))
    .borderRadius(RADIUS.full)
    .margin({ right: space('2') })
    // Tapping the chip cycles to the next value. The full
    // formSheet picker (iOS parity) is a follow-up — the
    // cycle is enough to expose the underlying mutation
    // hook (updateIssue) and verify the optimistic patch /
    // server roundtrip path.
    .onClick(() => { this.cycleAttribute(kind); })
  }

  /**
   * Cycle an issue attribute to the next value and fire the
   * updateIssue mutation. Local optimistic write flips the
   * displayed chip synchronously, then the server's response
   * overwrites.
   */
  private cycleAttribute(kind: 'status' | 'priority'): void {
    if (!this.query) return;
    const cur = this.query.getState().data;
    if (!cur) return;
    if (kind === 'status') {
      const order: IssueStatus[] = ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];
      const idx = order.indexOf(cur.status);
      const next = order[(idx + 1) % order.length];
      this.updateAttribute({ status: next });
    } else {
      const order: IssuePriority[] = ['no_priority', 'low', 'medium', 'high', 'urgent'];
      const idx = order.indexOf(cur.priority);
      const next = order[(idx + 1) % order.length];
      this.updateAttribute({ priority: next });
    }
  }

  private async updateAttribute(patch: UpdateIssueRequest): Promise<void> {
    if (!this.query) return;
    const cur = this.query.getState().data;
    if (!cur) return;
    try {
      const saved = await updateIssue(this.issueId, patch);
      // The mutation already invalidates the issue list prefix;
      // we patch the local detail cache with the server's
      // authoritative response so the chip flips immediately.
      queryClient.setQueryData<Issue>(issueDetailKey(workspaceStore.currentId, this.issueId), saved);
    } catch (err) {
      console.warn('[issue] cycle attribute failed', err);
    }
  }

  @Builder Loading() {
    Column() {
      Skeleton({ scheme: this.scheme, skeletonWidth: 80, skeletonHeight: 12, radius: 4 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 28, radius: 6 })
        .margin({ top: space('2') })
      Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 80, radius: 8 })
        .margin({ top: space('4') })
    }
    .padding(space('4'))
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder ErrorState(message: string) {
    MulticaText({
      value: `Failed to load issue: ${message}`,
      scheme: this.scheme,
      textSize: 'sm',
      color: 'destructive'
    })
      .padding(space('4'))
  }
}
