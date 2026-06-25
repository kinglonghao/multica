import hilog from '@ohos.hilog';
import { appNavigation } from '../data/navigation';
import { globalEvents } from '../data/auth';
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
import { detectSystemColorScheme } from '../lib/theme-manager';
import { timeAgo } from '../lib/utils';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { MarkdownText } from '../components/ui/MarkdownText';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { StatusIcon } from '../components/ui/StatusIcon';
import { PriorityIcon } from '../components/ui/PriorityIcon';
import { Avatar } from '../components/ui/Avatar';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { Card } from '../components/ui/Card';
import { Issue, Comment, IssueStatus, IssuePriority, UpdateIssueRequest, Agent, MemberWithUser } from '../models/types';

interface DisplayComment {
  id: string;
  issue_id: string;
  body: string;
  content?: string | null;
  author_id: string;
  author_name?: string | null;
  author_avatar_url?: string | null;
  author_type?: 'member' | 'agent' | null;
  created_at: string;
  updated_at: string;
  edited?: boolean;
  reactions?: Object[];
  display_author_name?: string | null;
  display_author_avatar_url?: string | null;
}

const COMMENTS_KEY = (id: string): readonly (string | number | boolean)[] => ['issue-comments', id];
const AGENTS_KEY = (wsId: string | null): readonly (string | number | boolean | null)[] => ['agents', wsId];
const MEMBERS_KEY = (wsId: string | null): readonly (string | number | boolean | null)[] => ['members', wsId];
const COMMENT_BOX_HEIGHT = 112;
const COMMENT_BOX_COLLAPSED_HEIGHT = 40;
const COMMENT_ROW_MIN_HEIGHT = 72;
const COMMENT_MAX_LENGTH = 2000;
const ISSUE_DETAIL_DEBUG_DOMAIN = 0xFF12;
const ISSUE_DETAIL_DEBUG_TAG = 'IssueDetailPage';

@ComponentV2
export struct IssueDetailPage {
  @Param issueId: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local commentDraft: string = '';
  @Local commentComposerExpanded: boolean = false;
  @Local sendingComment: boolean = false;
  @Local commentError: string = '';
  @Local editingCommentId: string = '';
  @Local editingDraft: string = '';
  @Local savingEdit: boolean = false;
  @Local _issueIsLoading: boolean = true;
  @Local _issue: Issue | undefined = undefined;
  @Local _issueError: Error | null = null;
  @Local _issueActorName: string = '';
  @Local _issueActorAvatar: string = '';
  @Local _pageReady: boolean = false;
  @Local _commentsIsLoading: boolean = true;
  @Local _comments: Comment[] | undefined = undefined;
  @Local _commentsError: Error | null = null;
  private headerScroller: Scroller = new Scroller();
  private query: QueryHandle<Issue> | null = null;
  private comments: QH<Comment[]> | null = null;
  private agents: QH<Agent[]> | null = null;
  private members: QH<MemberWithUser[]> | null = null;
  private wsUnsub?: () => void;
  private globalUnsub?: () => void;
  private workspaceChangedUnsub?: () => void;

  // #region debug-point issue-detail-log
  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(ISSUE_DETAIL_DEBUG_DOMAIN, ISSUE_DETAIL_DEBUG_TAG,
      `stage=${stage} issueId=${this.issueId} ${extra}`);
  }

  private debugError(stage: string, err: Object | null = null): void {
    const message = err instanceof Error ? err.message : `${err ?? 'unknown'}`;
    hilog.error(ISSUE_DETAIL_DEBUG_DOMAIN, ISSUE_DETAIL_DEBUG_TAG,
      `stage=${stage} issueId=${this.issueId} error=${message}`);
  }
  // #endregion

  aboutToAppear(): void {
    this.debugInfo('aboutToAppear:start', `workspace=${workspaceStore.currentId ?? 'null'}`);
    this.scheme = this.detectScheme();
    const wsId = workspaceStore.currentId;
    this.query = useIssueDetailQuery(this.issueId, () => {
      this.version++;
      this.syncFromCache();
    });
    this.comments = useQuery<Comment[]>(
      COMMENTS_KEY(this.issueId),
      (ctx: FetchContext) => api.listComments(this.issueId, { cancelToken: ctx.cancelToken }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.agents = useQuery<Agent[]>(
      AGENTS_KEY(wsId),
      (ctx: FetchContext) => api.listAgents({ cancelToken: ctx.cancelToken }),
      { staleTimeMs: 60_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.members = useQuery<MemberWithUser[]>(
      MEMBERS_KEY(wsId),
      (ctx: FetchContext) => api.listMembers(wsId ?? '', { cancelToken: ctx.cancelToken }),
      { staleTimeMs: 60_000, onUpdate: () => { this.version++; this.syncFromCache(); } }
    );
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    this.wsUnsub = useIssueRealtime(this.issueId);
    this.debugInfo('aboutToAppear:end');
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.comments?.unsubscribe();
    this.agents?.unsubscribe();
    this.members?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private syncFromCache(): void {
    try {
      const currentWsId = workspaceStore.currentId;
      const issueWsId = this._issue?.workspace_id ?? this.query?.getState().data?.workspace_id ?? 'null';
      this.debugInfo('sync:workspace', `current=${currentWsId ?? 'null'} issueWorkspace=${issueWsId}`);
      if (this.query) {
        const s = this.query.getState();
        this._issueIsLoading = s.isLoading;
        this._issue = s.data as Issue | undefined;
        this._issueError = s.error;
        this.debugInfo('sync:issue', `loading=${s.isLoading} hasData=${s.data !== undefined} error=${s.error ? s.error.message : 'none'}`);
      }
      this._pageReady = this._pageReady || this._issue !== undefined || this._issueError !== null;
      if (this.comments) {
        const s = this.comments.getState();
        this._commentsIsLoading = s.isLoading;
        this._comments = s.data as Comment[] | undefined;
        this._commentsError = s.error;
        this.debugInfo('sync:comments', `loading=${s.isLoading} count=${s.data ? s.data.length : -1} error=${s.error ? s.error.message : 'none'}`);
      }
      if (this.agents) {
        const s = this.agents.getState();
        const count = s.data ? s.data.length : -1;
        const first = s.data && s.data.length > 0 ? `${s.data[0].id}:${s.data[0].name}` : 'none';
        this.debugInfo('sync:agents', `loading=${s.isLoading} count=${count} first=${first} error=${s.error ? s.error.message : 'none'}`);
      }
      if (this.members) {
        const s = this.members.getState();
        const count = s.data ? s.data.length : -1;
        this.debugInfo('sync:members', `loading=${s.isLoading} count=${count} error=${s.error ? s.error.message : 'none'}`);
      }
    } catch (err) {
      this.debugError('syncFromCache:throw', err as Object);
      const normalizedError = err instanceof Error ? err : new Error(`${err ?? 'syncFromCache failed'}`);
      throw normalizedError;
    }
  }

  private async submitComment(): Promise<void> {
    const text = this.commentDraft.trim();
    if (!text || this.sendingComment) return;
    this.debugInfo('submitComment:start', `draftLen=${text.length} existingComments=${this._comments ? this._comments.length : -1}`);
    this.sendingComment = true;
    this.commentError = '';
    try {
      await createComment(this.issueId, text);
      this.debugInfo('submitComment:created', `draftLen=${text.length}`);
      this.commentDraft = '';
      this.commentComposerExpanded = false;
      this.comments?.refetch();
      this.debugInfo('submitComment:refetch-requested');
    } catch (err) {
      this.debugError('submitComment:catch', err as Object);
      this.commentError = err instanceof Error ? err.message : 'Failed to post comment';
    } finally {
      this.sendingComment = false;
      this.debugInfo('submitComment:finally', `sending=${this.sendingComment} error=${this.commentError || 'none'}`);
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

  private collapseCommentComposer(): void {
    if (this.commentDraft.trim().length > 0 || this.sendingComment) return;
    this.commentComposerExpanded = false;
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

  private issueActorName(issue: Issue): string {
    if (issue.assignee_name && issue.assignee_name.trim().length > 0) return issue.assignee_name;
    if (issue.assignee_id) {
      const resolved = this.actorName(issue.assignee_type ?? null, issue.assignee_id);
      if (resolved) return resolved;
    }
    if (issue.assignee_type === 'agent') return 'Agent';
    if (issue.creator_name && issue.creator_name.trim().length > 0) return issue.creator_name;
    if (issue.creator_id) {
      const resolved = this.actorName('member', issue.creator_id);
      if (resolved) return resolved;
    }
    return 'Unassigned';
  }

  private issueActorAvatar(issue: Issue): string {
    if (issue.assignee_avatar_url && issue.assignee_avatar_url.trim().length > 0) return issue.assignee_avatar_url;
    if (issue.assignee_id) {
      const resolved = this.actorAvatar(issue.assignee_type ?? null, issue.assignee_id);
      if (resolved) return resolved;
    }
    if (issue.creator_avatar_url && issue.creator_avatar_url.trim().length > 0) return issue.creator_avatar_url;
    if (issue.creator_id) {
      const resolved = this.actorAvatar('member', issue.creator_id);
      if (resolved) return resolved;
    }
    return '';
  }

  private issueActorLabel(issue: Issue): string {
    if (issue.assignee_id) return 'Assignee';
    if (issue.creator_id) return 'Creator';
    return 'Owner';
  }

  private issueActorRenderKey(issue: Issue): string {
    return `${issue.id}:${this.issueActorLabel(issue)}:${this.issueActorName(issue)}:${this.issueActorAvatar(issue)}`;
  }

  private resolveCommentAuthorName(c: Comment, issue: Issue | undefined): string {
    if (c.author_name && c.author_name.trim().length > 0) return c.author_name;
    const resolved = this.actorName(c.author_type ?? null, c.author_id);
    if (resolved) return resolved;
    if (c.author_type === 'agent') {
      if (issue?.assignee_type === 'agent' && issue.assignee_id === c.author_id) {
        return this.issueActorName(issue);
      }
      return 'Agent';
    }
    if (issue?.creator_id === c.author_id && issue.creator_name && issue.creator_name.trim().length > 0) return issue.creator_name;
    if (issue?.assignee_id === c.author_id && issue.assignee_name && issue.assignee_name.trim().length > 0) return issue.assignee_name;
    return 'Unknown';
  }

  private resolveCommentAuthorAvatar(c: Comment, issue: Issue | undefined): string {
    if (c.author_avatar_url && c.author_avatar_url.trim().length > 0) return c.author_avatar_url;
    const resolved = this.actorAvatar(c.author_type ?? null, c.author_id);
    if (resolved) return resolved;
    if (issue?.creator_id === c.author_id && issue.creator_avatar_url && issue.creator_avatar_url.trim().length > 0) return issue.creator_avatar_url;
    if (issue?.assignee_id === c.author_id && issue.assignee_avatar_url && issue.assignee_avatar_url.trim().length > 0) return issue.assignee_avatar_url;
    return '';
  }

  private commentAuthorName(c: Comment, issue: Issue | undefined): string {
    const displayComment = c as DisplayComment;
    const result = displayComment.display_author_name ?? this.resolveCommentAuthorName(c, issue);
    this.debugInfo('commentAuthorName',
      `commentId=${c.id} authorType=${c.author_type ?? 'null'} authorId=${c.author_id} authorName=${c.author_name ?? '<null>'} result=${result}`);
    return result;
  }

  private commentAuthorAvatar(c: Comment, issue: Issue | undefined): string {
    const displayComment = c as DisplayComment;
    const result = displayComment.display_author_avatar_url ?? this.resolveCommentAuthorAvatar(c, issue);
    this.debugInfo('commentAuthorAvatar',
      `commentId=${c.id} authorType=${c.author_type ?? 'null'} authorId=${c.author_id} authorAvatar=${c.author_avatar_url ?? '<null>'} result=${result || '<empty>'}`);
    return result;
  }

  private actorName(type: string | null, id: string | null | undefined): string {
    if (!type || !id) {
      this.debugInfo('actorName:skip', `type=${type ?? 'null'} id=${id ?? 'null'}`);
      return '';
    }
    if (type === 'agent') {
      const agents = this.agents?.getState().data;
      const count = agents ? agents.length : -1;
      if (!agents) {
        this.debugInfo('actorName:agent-no-data', `id=${id} count=${count}`);
        return '';
      }
      const found = agents.find((agent: Agent) => agent.id === id);
      this.debugInfo('actorName:agent', `id=${id} count=${count} found=${found ? 'yes' : 'no'} name=${found?.name ?? '<empty>'}`);
      return found ? found.name : '';
    }
    if (type === 'member') {
      const members = this.members?.getState().data;
      if (!members) return '';
      const found = members.find((member: MemberWithUser) => member.user_id === id);
      return found?.name ?? found?.email ?? found?.user?.display_name ?? found?.user?.username ?? found?.user?.email ?? '';
    }
    return '';
  }

  private actorAvatar(type: string | null, id: string | null | undefined): string {
    if (!type || !id) return '';
    if (type === 'agent') {
      const agents = this.agents?.getState().data;
      if (!agents) return '';
      const found = agents.find((agent: Agent) => agent.id === id);
      return found?.avatar_url ?? '';
    }
    if (type === 'member') {
      const members = this.members?.getState().data;
      if (!members) return '';
      const found = members.find((member: MemberWithUser) => member.user_id === id);
      return found?.avatar_url ?? found?.user?.avatar_url ?? '';
    }
    return '';
  }

  private commentBody(c: Comment): string {
    const body = c.body && c.body.trim().length > 0 ? c.body : (c.content && c.content.trim().length > 0 ? c.content : '');
    this.debugInfo('commentBody', `commentId=${c.id} bodyLen=${body.length} hasBody=${c.body ? 'yes' : 'no'} hasContent=${c.content ? 'yes' : 'no'}`);
    return body;
  }

  build() {
    Column() {
      Header({
        title: this.issueId ? 'Issue' : 'Loading…',
        scheme: this.scheme,
        left: (): void => { this.BackButton(); }
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
    if ((this._issue === undefined && this._issueError === null) || this._issueIsLoading) {
      if (this._pageReady && this._comments && this._comments.length > 0) {
        Column() {
          Scroll() {
            Column() {
              this.Timeline()
            }
            .width('100%')
            .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('6') })
            .alignItems(HorizontalAlign.Start)
          }
          .layoutWeight(1)
          .width('100%')

          this.Composer()
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        this.Loading()
      }
    } else if (this._issueError) {
      this.ErrorState(this._issueError.message)
    } else if (this._issue) {
      Column() {
        Scroll() {
          Column() {
            this.IssueHeader(this._issue!)
            this.Timeline()
          }
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('6') })
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')

        this.Composer()
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
        textSize: '2xl',
        weight: 'bold',
        color: 'foreground',
        maxLines: 3,
        overflow: 'ellipsis'
      })
        .margin({ top: space('2') })

      Scroll(this.headerScroller) {
        Row() {
          this.AttributeChip(issue.status, 'status')
          this.AttributeChip(issue.priority, 'priority')
        }
        .alignItems(VerticalAlign.Center)
        .width('100%')
      }
      .margin({ top: space('3') })
      .scrollBar(BarState.Off)
      .scrollable(ScrollDirection.Horizontal)

      if (issue.description) {
        Column() {
          Card({ scheme: this.scheme, contentPadding: space('4'), gap: space('2') }) {
            Column({ space: space('2') }) {
              MulticaText({
                value: 'Description',
                scheme: this.scheme,
                textSize: 'sm',
                weight: 'semibold',
                color: 'mutedForeground'
              })
              MarkdownText({
                value: issue.description ?? '',
                scheme: this.scheme
              })
            }
            .alignItems(HorizontalAlign.Start)
          }
        }
        .margin({ top: space('4') })
        .width('100%')
      }

      Column() {
        ForEach([this.issueActorRenderKey(issue)], (_actorKey: string) => {
          Card({ scheme: this.scheme, contentPadding: space('4') }) {
            Column({ space: space('3') }) {
              Row() {
                Avatar({ name: this.issueActorName(issue), url: this.issueActorAvatar(issue), avatarSize: 36, scheme: this.scheme })
                Column({ space: space('0.5') }) {
                  MulticaText({
                    value: this.issueActorLabel(issue),
                    scheme: this.scheme,
                    textSize: 'xs',
                    color: 'mutedForeground',
                    weight: 'medium'
                  })
                  MulticaText({
                    value: this.issueActorName(issue),
                    scheme: this.scheme,
                    textSize: 'sm',
                    color: 'foreground',
                    weight: 'medium'
                  })
                }
                .margin({ left: space('3') })
                .alignItems(HorizontalAlign.Start)
                Blank()
              }

              MulticaText({
                value: `Created ${timeAgo(issue.created_at)} · Updated ${timeAgo(issue.updated_at)}`,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }
        }, (actorKey: string) => actorKey)
      }
      .margin({ top: space('4') })
      .width('100%')

      MulticaText({
        value: 'Activity',
        scheme: this.scheme,
        textSize: 'md',
        weight: 'semibold',
        color: 'foreground'
      })
        .margin({ top: space('6') })
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder Timeline() {
    if (this._commentsIsLoading) {
      Column({ space: space('3') }) {
        ForEach([1, 2, 3], () => {
          Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 88, radius: 12 })
        })
      }
      .width('100%')
      .margin({ top: space('3') })
      .alignItems(HorizontalAlign.Start)
    } else if (this._commentsError) {
      Column() {
        Card({ scheme: this.scheme, contentPadding: space('4') }) {
          MulticaText({
            value: `Failed to load activity: ${this._commentsError.message}`,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'destructive'
          })
        }
      }
      .width('100%')
      .margin({ top: space('3') })
    } else if (this._comments && this._comments!.length > 0) {
      Column({ space: space('3') }) {
        ForEach(this._comments!, (c: Comment) => {
          this.CommentRow(c)
        }, (c: Comment) => `${c.id}:${this.commentAuthorName(c, this._issue)}:${this.commentAuthorAvatar(c, this._issue)}`)
      }
      .width('100%')
      .margin({ top: space('3') })
      .alignItems(HorizontalAlign.Start)
    } else {
      Column() {
        Card({ scheme: this.scheme, contentPadding: space('4') }) {
          MulticaText({
            value: 'No activity yet. Be the first to comment.',
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground'
          })
        }
      }
      .width('100%')
      .margin({ top: space('3') })
    }
  }

  @Builder CommentRow(c: Comment) {
    Column() {
      Card({ scheme: this.scheme, contentPadding: space('4') }) {
        Column({ space: space('2') }) {
          Row() {
            Avatar({ name: this.commentAuthorName(c, this._issue), url: this.commentAuthorAvatar(c, this._issue), avatarSize: 36, scheme: this.scheme })
            Column({ space: space('0.5') }) {
              MulticaText({
                value: this.commentAuthorName(c, this._issue),
                scheme: this.scheme,
                textSize: 'sm',
                weight: 'semibold',
                color: 'foreground'
              })
              MulticaText({
                value: timeAgo(c.created_at),
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
            }
            .layoutWeight(1)
            .margin({ left: space('3') })
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          if (this.editingCommentId === c.id) {
            TextArea({ text: this.editingDraft })
              .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
              .fontColor(String(themeTokens(this.scheme).foreground))
              .backgroundColor(String(themeTokens(this.scheme).background))
              .borderRadius(RADIUS.md)
              .padding(space('3'))
              .width('100%')
              .height(96)
              .onChange((value: string) => { this.editingDraft = value; })
            Row() {
              MulticaButton({
                label: this.savingEdit ? 'Saving…' : 'Save',
                scheme: this.scheme,
                variant: 'primary',
                buttonSize: 'sm',
                disabled: this.savingEdit || this.editingDraft.trim().length === 0,
                onTap: () => { void this.saveEdit(); }
              })
              MulticaButton({
                label: 'Cancel',
                scheme: this.scheme,
                variant: 'ghost',
                buttonSize: 'sm',
                onTap: () => { this.cancelEditing(); }
              })
                .margin({ left: space('2') })
            }
          } else {
            MarkdownText({
              value: this.commentBody(c),
              scheme: this.scheme,
              compact: true
            })
              .width('100%')

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
        .width('100%')
        .constraintSize({ minHeight: COMMENT_ROW_MIN_HEIGHT })
        .padding({ right: space('1') })
        .alignItems(HorizontalAlign.Start)
      }
    }
    .width('100%')
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
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('2') })
      }

      Column() {
        Card({
          scheme: this.scheme,
          contentPadding: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('3') : space('2.5')
        }) {
          Column({
            space: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('2.5') : space('2')
          }) {
            if (this.commentComposerExpanded || this.commentDraft.trim().length > 0) {
              Row() {
                MulticaText({
                  value: 'Comment',
                  scheme: this.scheme,
                  textSize: 'sm',
                  weight: 'semibold',
                  color: 'foreground'
                })
                Blank()
                if (!this.sendingComment && this.commentDraft.trim().length === 0) {
                  MulticaText({
                    value: 'Close',
                    scheme: this.scheme,
                    textSize: 'xs',
                    weight: 'medium',
                    color: 'mutedForeground'
                  })
                    .onClick(() => { this.collapseCommentComposer(); })
                    .margin({ right: space('3') })
                }
                MulticaText({
                  value: `${this.commentDraft.length}/${COMMENT_MAX_LENGTH}`,
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: this.commentDraft.length > 1600 ? 'warning' : 'mutedForeground'
                })
              }
              .width('100%')
            }

            TextArea({ placeholder: 'Write a comment…', text: this.commentDraft })
              .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
              .fontColor(String(themeTokens(this.scheme).foreground))
              .caretColor(String(themeTokens(this.scheme).brand))
              .backgroundColor(String(themeTokens(this.scheme).card))
              .borderRadius(RADIUS.lg)
              .padding({
                left: space('3'),
                right: space('3'),
                top: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('3') : space('2.5'),
                bottom: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('3') : space('2.5')
              })
              .width('100%')
              .height(this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? COMMENT_BOX_HEIGHT : COMMENT_BOX_COLLAPSED_HEIGHT)
              .maxLength(COMMENT_MAX_LENGTH)
              .barState(BarState.Auto)
              .showCounter(this.commentComposerExpanded || this.commentDraft.trim().length > 0, {
                thresholdPercentage: 80,
                highlightBorder: true
              })
              .onClick(() => { this.commentComposerExpanded = true; })
              .onChange((value: string) => {
                this.commentDraft = value;
                if (value.trim().length > 0) this.commentComposerExpanded = true;
              })
              .onBlur(() => { this.collapseCommentComposer(); })

            if (this.commentComposerExpanded || this.commentDraft.trim().length > 0) {
              Row() {
                MulticaText({
                  value: 'Supports multiline input',
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'mutedForeground'
                })
                Blank()
                MulticaButton({
                  label: this.sendingComment ? 'Posting…' : 'Comment',
                  scheme: this.scheme,
                  variant: 'primary',
                  buttonSize: 'sm',
                  disabled: this.sendingComment || this.commentDraft.trim().length === 0,
                  onTap: () => { void this.submitComment(); }
                })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .padding({
        left: space('4'),
        right: space('4'),
        top: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('3') : space('2'),
        bottom: this.commentComposerExpanded || this.commentDraft.trim().length > 0 ? space('4') : space('2')
      })
      .backgroundColor(String(themeTokens(this.scheme).background))
      .border({
        width: { top: 1 },
        color: String(themeTokens(this.scheme).border)
      })
    }
    .width('100%')
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
    .onClick(() => { this.cycleAttribute(kind); })
  }

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
      queryClient.setQueryData<Issue>(issueDetailKey(workspaceStore.currentId, this.issueId), saved);
    } catch (err) {
      console.warn('[issue] cycle attribute failed', err);
    }
  }

  @Builder Loading() {
    Column({ space: space('3') }) {
      Skeleton({ scheme: this.scheme, skeletonWidth: 72, skeletonHeight: 12, radius: 4 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 32, radius: 8 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '72%', skeletonHeight: 18, radius: 8 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 152, radius: 12 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 88, radius: 12 })
      Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 88, radius: 12 })
    }
    .padding(space('4'))
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder ErrorState(message: string) {
    Column() {
      Card({ scheme: this.scheme, contentPadding: space('4') }) {
        MulticaText({
          value: `Failed to load issue: ${message}`,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
      }
    }
    .width('100%')
    .padding(space('4'))
  }
}
