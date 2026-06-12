import http from '@ohos.net.http';
import { BusinessError } from '@ohos.base';
import { Preferences } from './preferences';
import {
  Agent,
  AgentTask,
  Attachment,
  ChatMessage,
  ChatPendingTask,
  ChatSession,
  Comment,
  CreateIssueRequest,
  CreateLabelRequest,
  CreateProjectRequest,
  CreateProjectResourceRequest,
  InboxItem,
  Issue,
  IssueLabelsResponse,
  IssueReaction,
  Label,
  ListIssuesParams,
  ListIssuesResponse,
  ListLabelsResponse,
  ListProjectResourcesResponse,
  ListProjectsResponse,
  LoginResponse,
  MemberWithUser,
  NotificationPreferences,
  PinnedItem,
  Project,
  ProjectResource,
  ReorderPinsRequest,
  RuntimeDevice,
  SearchIssuesResponse,
  SearchProjectsResponse,
  SendChatMessageResponse,
  Squad,
  UpdateIssueRequest,
  UpdateProjectRequest,
  User,
  Workspace
} from '../models/types';
import { parseWithFallback } from '../lib/parse-response';
import {
  AgentTaskListSchema,
  ChatMessageListSchema,
  CommentListSchema,
  CommentSchema,
  EMPTY_AGENT_TASK_LIST,
  EMPTY_CHAT_MESSAGE_LIST,
  EMPTY_COMMENT,
  EMPTY_COMMENT_LIST,
  EMPTY_INBOX_LIST,
  EMPTY_ISSUE,
  EMPTY_LIST_ISSUES_RESPONSE,
  EMPTY_LIST_PROJECTS_RESPONSE,
  EMPTY_PROJECT,
  InboxListSchema,
  IssueSchema,
  ListIssuesResponseSchema,
  ListProjectsResponseSchema,
  ProjectSchema
} from '../lib/schemas';

/**
 * Mobile-owned fetch wrapper. Mirrors the iOS ApiClient (apps/mobile/data/api.ts).
 *
 * Design checklist (mirroring apps/mobile/CLAUDE.md "ApiClient capability list"):
 *   1. Schema validation via parseWithFallback (drift defense). Every read
 *      endpoint that returns a typed entity the UI renders — Issue, Comment,
 *      Project, InboxItem, AgentTask, ChatMessage + their list envelopes —
 *      runs the response body through a Schema and falls back to a safe
 *      EMPTY_* on failure. The iOS implementation has this for every
 *      endpoint; we have it for the M1-stability-critical surface and grow
 *      the coverage incrementally. See `lib/schemas.ets` for the per-type
 *      validators and `lib/parse-response.ets` for the helper.
 *   2. onUnauthorized callback on 401 (auto sign-out, avoids retry loops)
 *   3. X-Request-ID per request + structured logger (debug + tracing)
 *   4. Bearer auth + X-Workspace-Slug — NOT cookie auth (no CSRF, no credentials)
 *
 * HarmonyOS specifics:
 *   - @ohos.net.http is the system HTTP client. We build a new request per
 *     call (the API is request-scoped; no persistent connection pooling).
 *   - 30s hard timeout is enforced via a Promise.race — see FETCH_TIMEOUT_MS.
 *   - AbortSignal-like cancellation: the request is destroyed in the cleanup
 *     branch of the race; on normal completion we destroy it eagerly to free
 *     sockets.
 */

const API_URL = 'https://api.multica.ai'; // Overridden in setBaseUrl() — see app init.

let BASE_URL = API_URL;

export function setBaseUrl(url: string): void {
  BASE_URL = url.replace(/\/+$/, '');
}

export function getBaseUrl(): string {
  return BASE_URL;
}

const FETCH_TIMEOUT_MS = 30_000;

export class ApiError extends Error {
  readonly status: number;
  readonly body?: string;
  constructor(message: string, status: number, body?: string) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.body = body;
  }
}

export interface ApiClientOptions {
  onUnauthorized?: () => void;
}

interface RequestOpts {
  signal?: AbortSignal;
  endpoint?: string;
}

function rid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

class ApiClient {
  private options: ApiClientOptions = {};

  setOptions(opts: ApiClientOptions): void {
    this.options = { ...this.options, ...opts };
  }

  private async request<T>(method: string, path: string, body?: unknown, opts: RequestOpts = {}): Promise<T> {
    const id = rid();
    const url = `${BASE_URL}${path}`;
    const token = Preferences.get('authToken');
    const slug = Preferences.get('workspaceSlug');
    const headers: Record<string, string> = {
      'X-Request-ID': id,
      'Content-Type': 'application/json',
      'Accept': 'application/json'
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (slug) headers['X-Workspace-Slug'] = slug;

    console.info(`[api] → ${method} ${path} rid=${id}`);
    const start = Date.now();

    const httpRequest = http.createHttp();
    const requestTask = httpRequest.request(url, {
      method: method as http.RequestMethod,
      header: headers,
      extraData: body !== undefined ? JSON.stringify(body) : undefined,
      connectTimeout: FETCH_TIMEOUT_MS,
      readTimeout: FETCH_TIMEOUT_MS
    });

    let timeoutHandle: ReturnType<typeof setTimeout> | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        httpRequest.destroy();
        reject(new ApiError('Request timeout', 0));
      }, FETCH_TIMEOUT_MS);
    });

    let externalAbortHandler: (() => void) | null = null;
    if (opts.signal) {
      if (opts.signal.aborted) {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
        throw new ApiError('Aborted', 0);
      }
      externalAbortHandler = (): void => {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
      };
      opts.signal.addEventListener('abort', externalAbortHandler);
    }

    try {
      const response = await Promise.race([requestTask, timeoutPromise]);
      if (timeoutHandle) clearTimeout(timeoutHandle);
      if (externalAbortHandler && opts.signal) {
        opts.signal.removeEventListener('abort', externalAbortHandler);
      }
      httpRequest.destroy();

      const status = response.responseCode;
      const rawBody = response.result as string;
      const duration = Date.now() - start;
      const logFn = status >= 500 ? console.error : status === 404 ? console.warn : console.info;
      logFn(`[api] ← ${status} ${path} rid=${id} dur=${duration}ms`);

      if (status === 401) {
        this.options.onUnauthorized?.();
        throw new ApiError('Unauthorized', 401, rawBody);
      }
      if (status < 200 || status >= 300) {
        throw new ApiError(`HTTP ${status}`, status, rawBody);
      }
      if (status === 204) {
        return undefined as unknown as T;
      }
      try {
        return JSON.parse(rawBody) as T;
      } catch {
        throw new ApiError('Invalid JSON response', status, rawBody);
      }
    } catch (err) {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      if (externalAbortHandler && opts.signal) {
        opts.signal.removeEventListener('abort', externalAbortHandler);
      }
      httpRequest.destroy();
      throw err;
    }
  }

  // -------- Auth --------

  async requestOtp(email: string): Promise<void> {
    await this.request('POST', '/api/auth/otp/request', { email });
  }

  async verifyOtp(email: string, code: string): Promise<LoginResponse> {
    return this.request<LoginResponse>('POST', '/api/auth/otp/verify', { email, code });
  }

  async getMe(opts?: RequestOpts): Promise<User> {
    return this.request<User>('GET', '/api/me', undefined, opts);
  }

  async updateMe(req: { display_name?: string; avatar_url?: string }, opts?: RequestOpts): Promise<User> {
    return this.request<User>('PATCH', '/api/me', req, opts);
  }

  // -------- Workspaces --------

  async listWorkspaces(opts?: RequestOpts): Promise<Workspace[]> {
    return this.request<Workspace[]>('GET', '/api/workspaces', undefined, opts);
  }

  // -------- Inbox --------

  async listInbox(opts?: RequestOpts): Promise<InboxItem[]> {
    // Drift-safe read: server may add a new field, drop one, or
    // change a type and we don't want a single bad row to take
    // down the inbox tab. Falls back to an empty array; the page
    // renders the empty state instead of a half-populated list.
    const raw = await this.request<unknown>('GET', '/api/inbox', undefined, opts);
    return parseWithFallback(raw, InboxListSchema, EMPTY_INBOX_LIST, {
      endpoint: 'GET /api/inbox'
    });
  }

  async markInboxRead(id: string): Promise<void> {
    await this.request('POST', `/api/inbox/${id}/read`);
  }

  async markAllInboxRead(): Promise<void> {
    await this.request('POST', '/api/inbox/read-all');
  }

  async archiveInbox(id: string): Promise<void> {
    await this.request('POST', `/api/inbox/${id}/archive`);
  }

  async archiveAllInbox(): Promise<void> {
    await this.request('POST', '/api/inbox/archive-all');
  }

  async archiveAllReadInbox(): Promise<void> {
    await this.request('POST', '/api/inbox/archive-read');
  }

  async archiveCompletedInbox(): Promise<void> {
    await this.request('POST', '/api/inbox/archive-completed');
  }

  // -------- Issues --------

  async listIssues(params: ListIssuesParams = {}, opts?: RequestOpts): Promise<ListIssuesResponse> {
    const search = new URLSearchParams();
    if (params.status) {
      const arr = Array.isArray(params.status) ? params.status : [params.status];
      arr.forEach(s => search.append('status', s));
    }
    if (params.priority) {
      const arr = Array.isArray(params.priority) ? params.priority : [params.priority];
      arr.forEach(p => search.append('priority', p));
    }
    if (params.assignee_id) search.set('assignee_id', params.assignee_id);
    if (params.project_id) search.set('project_id', params.project_id);
    if (params.search) search.set('search', params.search);
    if (params.page) search.set('page', String(params.page));
    if (params.page_size) search.set('page_size', String(params.page_size));
    const qs = search.toString();
    const raw = await this.request<unknown>(
      'GET',
      `/api/issues${qs ? '?' + qs : ''}`,
      undefined,
      opts
    );
    return parseWithFallback(raw, ListIssuesResponseSchema, EMPTY_LIST_ISSUES_RESPONSE, {
      endpoint: 'GET /api/issues'
    });
  }

  async getIssue(id: string, opts?: RequestOpts): Promise<Issue> {
    // Drift-safe read: the issue detail page checks
    // `issue.id === ''` to render the "issue not found / shape
    // drifted" error state instead of a half-populated page.
    const raw = await this.request<unknown>('GET', `/api/issues/${id}`, undefined, opts);
    return parseWithFallback(raw, IssueSchema, EMPTY_ISSUE, {
      endpoint: 'GET /api/issues/:id'
    });
  }

  async createIssue(req: CreateIssueRequest): Promise<Issue> {
    return this.request<Issue>('POST', '/api/issues', req);
  }

  async updateIssue(id: string, req: UpdateIssueRequest): Promise<Issue> {
    return this.request<Issue>('PATCH', `/api/issues/${id}`, req);
  }

  async archiveIssue(id: string): Promise<void> {
    await this.request('DELETE', `/api/issues/${id}/archive`);
  }

  // -------- Timeline / Comments --------

  async getTimeline(issueId: string, opts?: RequestOpts): Promise<{ entries: unknown[] }> {
    return this.request<{ entries: unknown[] }>('GET', `/api/issues/${issueId}/timeline`, undefined, opts);
  }

  async listComments(issueId: string, opts?: RequestOpts): Promise<Comment[]> {
    const raw = await this.request<unknown>('GET', `/api/issues/${issueId}/comments`, undefined, opts);
    return parseWithFallback(raw, CommentListSchema, EMPTY_COMMENT_LIST, {
      endpoint: 'GET /api/issues/:id/comments'
    });
  }

  async createComment(issueId: string, body: string, opts?: RequestOpts): Promise<Comment> {
    // Write endpoint that returns a Comment. We still validate
    // the response shape so a server-side drift doesn't corrupt
    // the optimistic update the mutation already applied to the
    // cache. Fallback yields `id: ''` so the onSuccess writer
    // detects drift and falls back to invalidate.
    const raw = await this.request<unknown>(
      'POST',
      `/api/issues/${issueId}/comments`,
      { body },
      { ...opts, endpoint: 'POST /api/issues/:id/comments' }
    );
    return parseWithFallback(raw, CommentSchema, EMPTY_COMMENT, {
      endpoint: 'POST /api/issues/:id/comments'
    });
  }

  async updateComment(commentId: string, body: string): Promise<Comment> {
    const raw = await this.request<unknown>('PATCH', `/api/comments/${commentId}`, { body });
    return parseWithFallback(raw, CommentSchema, EMPTY_COMMENT, {
      endpoint: 'PATCH /api/comments/:id'
    });
  }

  async deleteComment(commentId: string): Promise<void> {
    await this.request('DELETE', `/api/comments/${commentId}`);
  }

  /**
   * Toggle a reaction on a comment. The server treats each
   * (comment_id, emoji, user_id) tuple as idempotent — repeated
   * calls from the same user with the same emoji remove the
   * existing reaction. The M2 client treats it as an add (the
   * optimistic patch in `mutations/issue.ts::reactToComment`
   * assumes a count++ outcome); the server returns whatever the
   * current state is and the post-settle invalidate in
   * `mutateDetail` will reconcile on the next refetch if the user
   * toggled.
   */
  async reactToComment(commentId: string, emoji: string): Promise<IssueReaction> {
    const raw = await this.request<unknown>(
      'POST',
      `/api/comments/${commentId}/reactions`,
      { emoji },
      { endpoint: 'POST /api/comments/:id/reactions' }
    );
    // Server contract: { id, comment_id, emoji, user_id, created_at }.
    // We accept the same loose-shape treatment as the rest of
    // the ApiClient — a partial response still gives the caller
    // something to write into the cache, and the post-settle
    // invalidate gives a clean re-fetch on the next user action.
    const r = (raw && typeof raw === 'object') ? (raw as Record<string, unknown>) : {};
    const id = typeof r['id'] === 'string' ? r['id'] as string : `temp-reaction-${Date.now()}`;
    const cId = typeof r['comment_id'] === 'string' ? r['comment_id'] as string : commentId;
    const em = typeof r['emoji'] === 'string' ? r['emoji'] as string : emoji;
    const uId = typeof r['user_id'] === 'string' ? r['user_id'] as string : '';
    const created = typeof r['created_at'] === 'string' ? r['created_at'] as string : new Date().toISOString();
    return { id, comment_id: cId, emoji: em, user_id: uId, created_at: created };
  }

  // -------- Projects --------

  async listProjects(opts?: RequestOpts): Promise<ListProjectsResponse> {
    const raw = await this.request<unknown>('GET', '/api/projects', undefined, opts);
    return parseWithFallback(raw, ListProjectsResponseSchema, EMPTY_LIST_PROJECTS_RESPONSE, {
      endpoint: 'GET /api/projects'
    });
  }

  async getProject(id: string, opts?: RequestOpts): Promise<Project> {
    // Drift-safe parse — UI checks `data.id === ""` to render the
    // "project not found / shape drifted" error state instead of
    // a half-populated detail page.
    const raw = await this.request<unknown>('GET', `/api/projects/${id}`, undefined, opts);
    return parseWithFallback(raw, ProjectSchema, EMPTY_PROJECT, {
      endpoint: 'GET /api/projects/:id'
    });
  }

  async createProject(req: CreateProjectRequest): Promise<Project> {
    return this.request<Project>('POST', '/api/projects', req);
  }

  async updateProject(id: string, req: UpdateProjectRequest): Promise<Project> {
    return this.request<Project>('PATCH', `/api/projects/${id}`, req);
  }

  async listProjectResources(projectId: string, opts?: RequestOpts): Promise<ListProjectResourcesResponse> {
    return this.request<ListProjectResourcesResponse>('GET', `/api/projects/${projectId}/resources`, undefined, opts);
  }

  async createProjectResource(projectId: string, req: CreateProjectResourceRequest): Promise<ProjectResource> {
    return this.request<ProjectResource>('POST', `/api/projects/${projectId}/resources`, req);
  }

  // -------- Labels --------

  async listLabels(opts?: RequestOpts): Promise<ListLabelsResponse> {
    return this.request<ListLabelsResponse>('GET', '/api/labels', undefined, opts);
  }

  async createLabel(req: CreateLabelRequest): Promise<Label> {
    return this.request<Label>('POST', '/api/labels', req);
  }

  async getIssueLabels(issueId: string, opts?: RequestOpts): Promise<IssueLabelsResponse> {
    return this.request<IssueLabelsResponse>('GET', `/api/issues/${issueId}/labels`, undefined, opts);
  }

  // -------- Chat --------

  async listChatSessions(opts?: RequestOpts): Promise<ChatSession[]> {
    return this.request<ChatSession[]>('GET', '/api/chat/sessions', undefined, opts);
  }

  async getChatSession(id: string, opts?: RequestOpts): Promise<ChatSession> {
    return this.request<ChatSession>('GET', `/api/chat/sessions/${id}`, undefined, opts);
  }

  async listChatMessages(sessionId: string, opts?: RequestOpts): Promise<ChatMessage[]> {
    const raw = await this.request<unknown>(
      'GET',
      `/api/chat/sessions/${sessionId}/messages`,
      undefined,
      opts
    );
    return parseWithFallback(raw, ChatMessageListSchema, EMPTY_CHAT_MESSAGE_LIST, {
      endpoint: 'GET /api/chat/sessions/:id/messages'
    });
  }

  async sendChatMessage(sessionId: string, body: string): Promise<SendChatMessageResponse> {
    return this.request<SendChatMessageResponse>('POST', `/api/chat/sessions/${sessionId}/messages`, { content: body });
  }

  // -------- Agents --------

  async listAgents(opts?: RequestOpts): Promise<Agent[]> {
    return this.request<Agent[]>('GET', '/api/agents', undefined, opts);
  }

  async listAgentTasks(agentId: string, opts?: RequestOpts): Promise<AgentTask[]> {
    const raw = await this.request<unknown>(
      'GET',
      `/api/agents/${agentId}/tasks`,
      undefined,
      opts
    );
    return parseWithFallback(raw, AgentTaskListSchema, EMPTY_AGENT_TASK_LIST, {
      endpoint: 'GET /api/agents/:id/tasks'
    });
  }

  /**
   * "Runs" for an issue — the agent tasks spawned by actions on the
   * issue (assign-to-agent, dispatch, etc.). Same shape as
   * `listAgentTasks`, filtered server-side to the issue. The
   * endpoint was added in M3 — a 404 (older server) falls back to
   * an empty list so the page renders the empty state instead of
   * crashing the issue detail.
   */
  async listIssueRuns(issueId: string, opts?: RequestOpts): Promise<AgentTask[]> {
    try {
      const raw = await this.request<unknown>(
        'GET',
        `/api/issues/${issueId}/runs`,
        undefined,
        opts
      );
      return parseWithFallback(raw, AgentTaskListSchema, EMPTY_AGENT_TASK_LIST, {
        endpoint: 'GET /api/issues/:id/runs'
      });
    } catch (err) {
      // 404 is expected on older servers — fall back to empty.
      if (err instanceof ApiError && err.status === 404) {
        return [] as AgentTask[];
      }
      throw err;
    }
  }

  // -------- Members --------

  async listMembers(opts?: RequestOpts): Promise<MemberWithUser[]> {
    return this.request<MemberWithUser[]>('GET', '/api/members', undefined, opts);
  }

  // -------- Squads --------

  async listSquads(opts?: RequestOpts): Promise<Squad[]> {
    return this.request<Squad[]>('GET', '/api/squads', undefined, opts);
  }

  // -------- Runtimes --------

  async listRuntimes(opts?: RequestOpts): Promise<RuntimeDevice[]> {
    return this.request<RuntimeDevice[]>('GET', '/api/runtimes', undefined, opts);
  }

  // -------- Pins --------

  async listPins(opts?: RequestOpts): Promise<PinnedItem[]> {
    return this.request<PinnedItem[]>('GET', '/api/pins', undefined, opts);
  }

  async addPin(itemId: string, itemType: 'issue' | 'project' | 'doc'): Promise<PinnedItem> {
    return this.request<PinnedItem>('POST', '/api/pins', { item_id: itemId, item_type: itemType });
  }

  async removePin(pinId: string): Promise<void> {
    await this.request('DELETE', `/api/pins/${pinId}`);
  }

  async reorderPins(req: ReorderPinsRequest): Promise<PinnedItem[]> {
    return this.request<PinnedItem[]>('POST', '/api/pins/reorder', req);
  }

  // -------- Notifications --------

  async getNotificationPreferences(opts?: RequestOpts): Promise<NotificationPreferences> {
    return this.request<NotificationPreferences>('GET', '/api/notifications/preferences', undefined, opts);
  }

  async updateNotificationPreferences(prefs: NotificationPreferences): Promise<NotificationPreferences> {
    return this.request<NotificationPreferences>('PUT', '/api/notifications/preferences', prefs);
  }

  // -------- Attachments --------

  async listAttachments(parentId: string, opts?: RequestOpts): Promise<Attachment[]> {
    return this.request<Attachment[]>('GET', `/api/attachments?parent_id=${parentId}`, undefined, opts);
  }

  /**
   * Multipart file upload. The shape mirrors the iOS FileAsset
   * (`apps/mobile/data/api.ts::uploadFile`) — a `{ uri, name, type }`
   * triple where `uri` is a HarmonyOS file descriptor (e.g. the
   * `PhotoAccessHelper` picker result, the `CameraPicker` output,
   * or a temp copy of an image the user picked for an avatar).
   *
   * The `@ohos.net.http` API takes a `multiFormDataList` array of
   * `{ name, contentType, filePath, remoteFileName? }` entries —
   * not the browser `FormData` shape. We translate our `file` /
   * `parentId` / `parentKind` payload into that array inline and
   * stay in lockstep with the iOS endpoint contract
   * (`POST /api/upload-file`, fields: `file`, `issue_id?`,
   * `comment_id?`).
   *
   * Why a dedicated path (not `this.request`):
   *   - `this.request` always serializes `extraData` as JSON and
   *     sets `Content-Type: application/json`. Multipart uploads
   *     need a boundary the runtime itself sets; passing our own
   *     `Content-Type` would suppress the boundary header and
   *     break the request.
   *   - The auth + 401 + structured-log shell is inlined here so
   *     the request still goes through the same `X-Request-ID` /
   *     `onUnauthorized` envelope as every other endpoint.
   *
   * The 30s hard timeout + signal handling from `this.request`
   * is re-implemented inline for the same reason. Future port to
   * the `request` helper would need a multipart-aware variant.
   */
  async uploadFile(
    file: { uri: string; name: string; type: string },
    opts: { issueId?: string; commentId?: string; signal?: AbortSignal } = {}
  ): Promise<Attachment> {
    const id = rid();
    const url = `${BASE_URL}/api/upload-file`;
    const token = Preferences.get('authToken');
    const slug = Preferences.get('workspaceSlug');
    const headers: Record<string, string> = {
      'X-Request-ID': id
      // Note: no Content-Type — the @ohos.net.http runtime sets
      // `multipart/form-data; boundary=…` once it sees
      // `multiFormDataList`.
    };
    if (token) headers['Authorization'] = `Bearer ${token}`;
    if (slug) headers['X-Workspace-Slug'] = slug;

    console.info(`[api] → POST /api/upload-file rid=${id} name=${file.name} type=${file.type}`);
    const start = Date.now();

    const multiFormDataList: http.MultiFormData[] = [
      {
        name: 'file',
        contentType: file.type || 'application/octet-stream',
        filePath: file.uri,
        remoteFileName: file.name
      }
    ];
    if (opts.issueId) {
      multiFormDataList.push({ name: 'issue_id', contentType: 'text/plain', data: opts.issueId });
    }
    if (opts.commentId) {
      multiFormDataList.push({ name: 'comment_id', contentType: 'text/plain', data: opts.commentId });
    }

    const httpRequest = http.createHttp();
    const requestTask = httpRequest.request(url, {
      method: http.RequestMethod.POST,
      header: headers,
      multiFormDataList,
      connectTimeout: FETCH_TIMEOUT_MS,
      readTimeout: FETCH_TIMEOUT_MS
    });

    let timeoutHandle: ReturnType<typeof setTimeout> | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        httpRequest.destroy();
        reject(new ApiError('Request timeout', 0));
      }, FETCH_TIMEOUT_MS);
    });

    let externalAbortHandler: (() => void) | null = null;
    if (opts.signal) {
      if (opts.signal.aborted) {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
        throw new ApiError('Aborted', 0);
      }
      externalAbortHandler = (): void => {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
      };
      opts.signal.addEventListener('abort', externalAbortHandler);
    }

    try {
      const response = await Promise.race([requestTask, timeoutPromise]);
      if (timeoutHandle) clearTimeout(timeoutHandle);
      if (externalAbortHandler && opts.signal) {
        opts.signal.removeEventListener('abort', externalAbortHandler);
      }
      httpRequest.destroy();

      const status = response.responseCode;
      const rawBody = response.result as string;
      const duration = Date.now() - start;
      const logFn = status >= 500 ? console.error : status === 404 ? console.warn : console.info;
      logFn(`[api] ← ${status} /api/upload-file rid=${id} dur=${duration}ms`);

      if (status === 401) {
        this.options.onUnauthorized?.();
        throw new ApiError('Unauthorized', 401, rawBody);
      }
      if (status < 200 || status >= 300) {
        throw new ApiError(`HTTP ${status}`, status, rawBody);
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(rawBody);
      } catch {
        throw new ApiError('Invalid JSON response', status, rawBody);
      }
      // Loose shape — the server contract is documented at
      // packages/core/api/schemas. We accept missing optional
      // fields and substitute the `id` / `url` the caller most
      // often needs (avatar / comment-image rendering). A server
      // contract drift logs a warning but does not throw — the
      // upload succeeded, the result is the broken part.
      if (!parsed || typeof parsed !== 'object') {
        console.warn(`[api] uploadFile: non-object response, treating as empty Attachment`);
        return {
          id: '',
          parent_id: opts.issueId ?? opts.commentId ?? '',
          url: '',
          name: file.name,
          content_type: file.type,
          size: 0,
          created_at: new Date().toISOString()
        } as Attachment;
      }
      const r = parsed as Record<string, unknown>;
      return {
        id: typeof r['id'] === 'string' ? r['id'] as string : '',
        parent_id:
          typeof r['parent_id'] === 'string'
            ? r['parent_id'] as string
            : (opts.issueId ?? opts.commentId ?? ''),
        url: typeof r['url'] === 'string' ? r['url'] as string : '',
        name: typeof r['name'] === 'string' ? r['name'] as string : file.name,
        content_type: typeof r['content_type'] === 'string' ? r['content_type'] as string : file.type,
        size: typeof r['size'] === 'number' ? r['size'] as number : 0,
        created_at: typeof r['created_at'] === 'string' ? r['created_at'] as string : new Date().toISOString()
      } as Attachment;
    } catch (err) {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      if (externalAbortHandler && opts.signal) {
        opts.signal.removeEventListener('abort', externalAbortHandler);
      }
      httpRequest.destroy();
      throw err;
    }
  }

  // -------- Search --------

  async searchIssues(query: string, opts?: RequestOpts): Promise<SearchIssuesResponse> {
    return this.request<SearchIssuesResponse>('GET', `/api/search/issues?q=${encodeURIComponent(query)}`, undefined, opts);
  }

  async searchProjects(query: string, opts?: RequestOpts): Promise<SearchProjectsResponse> {
    return this.request<SearchProjectsResponse>('GET', `/api/search/projects?q=${encodeURIComponent(query)}`, undefined, opts);
  }
}

export const api: ApiClient = new ApiClient();
