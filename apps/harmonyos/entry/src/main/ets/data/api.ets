import http from '@ohos.net.http';
import fs from '@ohos.file.fs';
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
import { ParseOptions, parseWithFallback } from '../lib/parse-response';
import { CancelToken } from '../queries/cache';
import {
  AgentTaskListSchema,
  AgentListSchema,
  ChatMessageListSchema,
  CommentListSchema,
  CommentSchema,
  EMPTY_AGENT_LIST,
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
 *   - CancelToken-based cancellation: the request is destroyed when the
 *     cache's CancelToken flips to aborted (or on the 30s timeout).
 */

const API_URL = 'http://multica.zliao.cc'; // Overridden in setBaseUrl() — see app init.

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

interface RequestHeaders {
  'X-Request-ID': string;
  'Content-Type': string;
  'Accept': string;
  'Authorization'?: string;
  'X-Workspace-Slug'?: string;
}

interface RequestOpts {
  cancelToken?: CancelToken;
  endpoint?: string;
}

interface UpdateMeRequest {
  display_name?: string;
  avatar_url?: string;
}

interface EmojiRequest {
  emoji: string;
}

interface SendChatMessageRequest {
  content: string;
}

interface PinRequest {
  item_id: string;
  item_type: 'issue' | 'project' | 'doc';
}

export interface UploadFileAsset {
  uri: string;
  name: string;
  type: string;
}

interface CreateCommentRequestBody {
  content: string;
  type: 'comment';
}

interface UpdateCommentRequestBody {
  content: string;
}

interface TimelineResponse {
  entries: Object[];
}

type RequestBody = Object | string | number | boolean | null;

interface RequestOtpBody {
  email: string;
}

interface VerifyOtpBody {
  email: string;
  code: string;
}

function rid(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36);
}

function appendQueryPart(parts: string[], key: string, value: string): void {
  parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(value)}`);
}

function buildIssueQueryString(params: ListIssuesParams): string {
  const parts: string[] = [];

  if (params.status) {
    const statuses = Array.isArray(params.status) ? params.status : [params.status];
    statuses.forEach((status) => appendQueryPart(parts, 'status', status));
  }
  if (params.priority) {
    const priorities = Array.isArray(params.priority) ? params.priority : [params.priority];
    priorities.forEach((priority) => appendQueryPart(parts, 'priority', priority));
  }
  if (params.assignee_id) appendQueryPart(parts, 'assignee_id', params.assignee_id);
  if (params.project_id) appendQueryPart(parts, 'project_id', params.project_id);
  if (params.search) appendQueryPart(parts, 'search', params.search);
  if (params.page) appendQueryPart(parts, 'page', String(params.page));
  if (params.page_size) appendQueryPart(parts, 'page_size', String(params.page_size));

  return parts.join('&');
}

class ApiClient {
  private options: ApiClientOptions = {};

  setOptions(opts: ApiClientOptions): void {
    if (opts.onUnauthorized !== undefined) {
      this.options.onUnauthorized = opts.onUnauthorized;
    }
  }

  private async request<T>(method: string, path: string, body?: RequestBody, opts: RequestOpts = {}): Promise<T> {
    const id = rid();
    const url = `${BASE_URL}${path}`;
    const token = Preferences.get('authToken');
    const slug = Preferences.get('workspaceSlug');
    const headers: RequestHeaders = {
      'X-Request-ID': id,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': token ? `Bearer ${token}` : undefined,
      'X-Workspace-Slug': slug ?? undefined
    };

    console.info(`[api] → ${method} ${path} rid=${id}`);
    const start = Date.now();

    const httpRequest = http.createHttp();
    let requestTask: Promise<http.HttpResponse>;
    try {
      requestTask = httpRequest.request(url, {
        method: method as http.RequestMethod,
        header: headers,
        extraData: body !== undefined ? JSON.stringify(body) : undefined,
        connectTimeout: FETCH_TIMEOUT_MS,
        readTimeout: FETCH_TIMEOUT_MS
      });
    } catch (err) {
      httpRequest.destroy();
      throw err instanceof Error ? err : new Error('Failed to create request');
    }

    let timeoutHandle: number | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        httpRequest.destroy();
        reject(new ApiError('Request timeout', 0));
      }, FETCH_TIMEOUT_MS);
    });

    let externalAbortHandler: (() => void) | null = null;
    if (opts.cancelToken) {
      if (opts.cancelToken.aborted) {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
        throw new ApiError('Aborted', 0);
      }
      externalAbortHandler = (): void => {
        httpRequest.destroy();
        if (timeoutHandle) clearTimeout(timeoutHandle);
      };
      opts.cancelToken.onAbort(externalAbortHandler);
    }

    try {
      const response = await Promise.race([requestTask, timeoutPromise]);
      if (timeoutHandle) clearTimeout(timeoutHandle);
      // CancelToken has no remove-listener API; the handler is a
      // no-op once the request has settled (httpRequest is already
      // destroyed below), so there is nothing to detach.
      httpRequest.destroy();

      const status = response.responseCode;
      const rawBody = response.result as string;
      const duration = Date.now() - start;
      const logFn = status >= 500 ? console.error : status === 404 ? console.warn : console.info;
      logFn(`[api] ← ${status} ${path} rid=${id} dur=${duration}ms`);
      // #region debug-point D:http-non-2xx
      if (status < 200 || status >= 300) {
        console.error(`[api] !! ${status} ${path} rid=${id} base=${BASE_URL} ws=${slug ?? '-'} body=${rawBody}`);
      }
      // #endregion

      if (status === 401) {
        this.options.onUnauthorized?.();
        throw new ApiError('Unauthorized', 401, rawBody);
      }
      if (status < 200 || status >= 300) {
        throw new ApiError(`HTTP ${status}`, status, rawBody);
      }
      if (status === 204) {
        return null as T;
      }
      try {
        return JSON.parse(rawBody) as T;
      } catch {
        throw new ApiError('Invalid JSON response', status, rawBody);
      }
    } catch (err) {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      // See note above: CancelToken has no remove-listener, and the
      // handler is harmless once httpRequest is destroyed.
      httpRequest.destroy();
      throw err instanceof Error ? err : new Error('Request failed');
    }
  }

  // -------- Auth --------

  async requestOtp(email: string): Promise<void> {
    const req: RequestOtpBody = { email };
    await this.request<void>('POST', '/auth/send-code', req);
  }

  async verifyOtp(email: string, code: string): Promise<LoginResponse> {
    const req: VerifyOtpBody = { email, code };
    return this.request<LoginResponse>('POST', '/auth/verify-code', req);
  }

  async getMe(opts?: RequestOpts): Promise<User> {
    return this.request<User>('GET', '/api/me', undefined, opts);
  }

  async updateMe(req: UpdateMeRequest, opts?: RequestOpts): Promise<User> {
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
    const raw = await this.request<Object>('GET', '/api/inbox', undefined, opts);
    return parseWithFallback(raw, InboxListSchema, EMPTY_INBOX_LIST, {
      endpoint: 'GET /api/inbox'
    });
  }

  async markInboxRead(id: string): Promise<void> {
    await this.request<void>('POST', `/api/inbox/${id}/read`);
  }

  async markAllInboxRead(): Promise<void> {
    await this.request<void>('POST', '/api/inbox/read-all');
  }

  async archiveInbox(id: string): Promise<void> {
    await this.request<void>('POST', `/api/inbox/${id}/archive`);
  }

  async archiveAllInbox(): Promise<void> {
    await this.request<void>('POST', '/api/inbox/archive-all');
  }

  async archiveAllReadInbox(): Promise<void> {
    await this.request<void>('POST', '/api/inbox/archive-read');
  }

  async archiveCompletedInbox(): Promise<void> {
    await this.request<void>('POST', '/api/inbox/archive-completed');
  }

  // -------- Issues --------

  async listIssues(params: ListIssuesParams = {}, opts?: RequestOpts): Promise<ListIssuesResponse> {
    const qs = buildIssueQueryString(params);
    const raw = await this.request<Object>(
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
    const raw = await this.request<Object>('GET', `/api/issues/${id}`, undefined, opts);
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
    await this.request<void>('DELETE', `/api/issues/${id}/archive`);
  }

  // -------- Timeline / Comments --------

  async getTimeline(issueId: string, opts?: RequestOpts): Promise<TimelineResponse> {
    return this.request<TimelineResponse>('GET', `/api/issues/${issueId}/timeline`, undefined, opts);
  }

  async listComments(issueId: string, opts?: RequestOpts): Promise<Comment[]> {
    const raw = await this.request<Object>('GET', `/api/issues/${issueId}/comments`, undefined, opts);
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
    const merged: RequestOpts = {
      endpoint: 'POST /api/issues/:id/comments'
    };
    if (opts) {
      merged.cancelToken = opts.cancelToken;
    }
    const req: CreateCommentRequestBody = {
      content: body,
      type: 'comment'
    };
    const parseOpts: ParseOptions = {
      endpoint: 'POST /api/issues/:id/comments'
    };
    const raw = await this.request<Object>(
      'POST',
      `/api/issues/${issueId}/comments`,
      req,
      merged
    );
    return parseWithFallback(raw, CommentSchema, EMPTY_COMMENT, parseOpts);
  }

  async updateComment(commentId: string, body: string): Promise<Comment> {
    const req: UpdateCommentRequestBody = { content: body };
    const parseOpts: ParseOptions = {
      endpoint: 'PATCH /api/comments/:id'
    };
    const raw = await this.request<Object>('PATCH', `/api/comments/${commentId}`, req);
    return parseWithFallback(raw, CommentSchema, EMPTY_COMMENT, parseOpts);
  }

  async deleteComment(commentId: string): Promise<void> {
    await this.request<void>('DELETE', `/api/comments/${commentId}`);
  }

  async reactToComment(commentId: string, emoji: string): Promise<IssueReaction> {
    // Replaces the raw fetch() that mutations/issue.ets used to call —
    // the reaction endpoint now goes through the same request() path
    // (Bearer auth, X-Workspace-Slug, X-Request-ID, timeout) as every
    // other write. The response shape matches server ReactionResponse
    // (id / comment_id / actor_type / actor_id / emoji / created_at),
    // which is exactly IssueReaction in models/types.ets.
    const req: EmojiRequest = { emoji };
    return this.request<IssueReaction>(
      'POST',
      `/api/comments/${commentId}/reactions`,
      req
    );
  }

  // -------- Projects --------

  async listProjects(opts?: RequestOpts): Promise<ListProjectsResponse> {
    const raw = await this.request<Object>('GET', '/api/projects', undefined, opts);
    return parseWithFallback(raw, ListProjectsResponseSchema, EMPTY_LIST_PROJECTS_RESPONSE, {
      endpoint: 'GET /api/projects'
    });
  }

  async getProject(id: string, opts?: RequestOpts): Promise<Project> {
    // Drift-safe parse — UI checks `data.id === ""` to render the
    // "project not found / shape drifted" error state instead of
    // a half-populated detail page.
    const raw = await this.request<Object>('GET', `/api/projects/${id}`, undefined, opts);
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
    const raw = await this.request<Object>(
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
    const req: SendChatMessageRequest = { content: body };
    return this.request<SendChatMessageResponse>('POST', `/api/chat/sessions/${sessionId}/messages`, req);
  }

  // -------- Agents --------

  async listAgents(opts?: RequestOpts): Promise<Agent[]> {
    const raw = await this.request<Object>('GET', '/api/agents', undefined, opts);
    return parseWithFallback(raw, AgentListSchema, EMPTY_AGENT_LIST, {
      endpoint: 'GET /api/agents'
    });
  }

  async listAgentTasks(agentId: string, opts?: RequestOpts): Promise<AgentTask[]> {
    const raw = await this.request<Object>(
      'GET',
      `/api/agents/${agentId}/tasks`,
      undefined,
      opts
    );
    return parseWithFallback(raw, AgentTaskListSchema, EMPTY_AGENT_TASK_LIST, {
      endpoint: 'GET /api/agents/:id/tasks'
    });
  }

  // -------- Members --------

  async listMembers(workspaceId: string, opts?: RequestOpts): Promise<MemberWithUser[]> {
    return this.request<MemberWithUser[]>(
      'GET',
      `/api/workspaces/${workspaceId}/members`,
      undefined,
      opts
    );
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
    const req: PinRequest = { item_id: itemId, item_type: itemType };
    return this.request<PinnedItem>('POST', '/api/pins', req);
  }

  async removePin(pinId: string): Promise<void> {
    await this.request<void>('DELETE', `/api/pins/${pinId}`);
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

  async uploadFile(parentId: string, file: UploadFileAsset): Promise<Attachment> {
    const id = rid();
    const url = `${BASE_URL}/api/attachments`;
    const token = Preferences.get('authToken');
    const slug = Preferences.get('workspaceSlug');
    
    console.info(`[api] → POST /api/attachments rid=${id} parentId=${parentId} filename=${file.name}`);
    const start = Date.now();

    // 读取文件内容
    let fileContent: ArrayBuffer;
    try {
      const fileStat = fs.statSync(file.uri);
      if (!fileStat.isFile()) {
        throw new Error(`Path ${file.uri} is not a file`);
      }
      
      const fd = fs.openSync(file.uri, fs.OpenMode.READ_ONLY);
      try {
        fileContent = new ArrayBuffer(fileStat.size);
        fs.readSync(fd.fd, fileContent);
      } finally {
        fs.closeSync(fd);
      }
    } catch (err) {
      console.error(`[api] Failed to read file ${file.uri}:`, err);
      throw new Error(`Failed to read file: ${err.message}`);
    }

    const httpRequest = http.createHttp();
    
    // 构建multipart/form-data请求
    const fileFormData: http.MultiFormData = {
      name: 'file',
      contentType: file.type || 'application/octet-stream',
      remoteFileName: file.name,
      data: fileContent
    };
    const multiFormDataList: http.MultiFormData[] = [fileFormData];

    // 添加其他表单数据
    const extraData = `parent_id=${encodeURIComponent(parentId)}`;

    const headers: RequestHeaders = {
      'X-Request-ID': id,
      'Content-Type': 'multipart/form-data',
      'Accept': 'application/json',
      'Authorization': token ? `Bearer ${token}` : undefined,
      'X-Workspace-Slug': slug ?? undefined
    };

    let requestTask: Promise<http.HttpResponse>;
    try {
      requestTask = httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: extraData,
        multiFormDataList: multiFormDataList,
        connectTimeout: FETCH_TIMEOUT_MS,
        readTimeout: FETCH_TIMEOUT_MS
      });
    } catch (err) {
      httpRequest.destroy();
      throw err instanceof Error ? err : new Error('Failed to create upload request');
    }

    let timeoutHandle: number | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
      timeoutHandle = setTimeout(() => {
        httpRequest.destroy();
        reject(new ApiError('Request timeout', 0));
      }, FETCH_TIMEOUT_MS);
    });

    try {
      const response = await Promise.race([requestTask, timeoutPromise]);
      if (timeoutHandle) clearTimeout(timeoutHandle);
      
      const status = response.responseCode;
      const rawBody = response.result as string;
      const duration = Date.now() - start;
      const logFn = status >= 500 ? console.error : status === 404 ? console.warn : console.info;
      logFn(`[api] ← ${status} /api/attachments rid=${id} dur=${duration}ms`);

      if (status === 401) {
        this.options.onUnauthorized?.();
        throw new ApiError('Unauthorized', 401, rawBody);
      }
      if (status < 200 || status >= 300) {
        throw new ApiError(`HTTP ${status}`, status, rawBody);
      }
      
      try {
        return JSON.parse(rawBody) as Attachment;
      } catch {
        throw new ApiError('Invalid JSON response', status, rawBody);
      }
    } catch (err) {
      if (timeoutHandle) clearTimeout(timeoutHandle);
      httpRequest.destroy();
      throw err instanceof Error ? err : new Error('Upload request failed');
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
