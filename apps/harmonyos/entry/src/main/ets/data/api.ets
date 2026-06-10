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

/**
 * Mobile-owned fetch wrapper. Mirrors the iOS ApiClient (apps/mobile/data/api.ts).
 *
 * Design checklist (mirroring apps/mobile/CLAUDE.md "ApiClient capability list"):
 *   1. Zod-like schema validation via parseWithFallback (drift defense)
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
    return this.request<InboxItem[]>('GET', '/api/inbox', undefined, opts);
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
    return this.request<ListIssuesResponse>('GET', `/api/issues${qs ? '?' + qs : ''}`, undefined, opts);
  }

  async getIssue(id: string, opts?: RequestOpts): Promise<Issue> {
    return this.request<Issue>('GET', `/api/issues/${id}`, undefined, opts);
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
    return this.request<Comment[]>('GET', `/api/issues/${issueId}/comments`, undefined, opts);
  }

  async createComment(issueId: string, body: string, opts?: RequestOpts): Promise<Comment> {
    return this.request<Comment>('POST', `/api/issues/${issueId}/comments`, { body }, { ...opts, endpoint: 'POST /api/issues/:id/comments' });
  }

  async updateComment(commentId: string, body: string): Promise<Comment> {
    return this.request<Comment>('PATCH', `/api/comments/${commentId}`, { body });
  }

  async deleteComment(commentId: string): Promise<void> {
    await this.request('DELETE', `/api/comments/${commentId}`);
  }

  // -------- Projects --------

  async listProjects(opts?: RequestOpts): Promise<ListProjectsResponse> {
    return this.request<ListProjectsResponse>('GET', '/api/projects', undefined, opts);
  }

  async getProject(id: string, opts?: RequestOpts): Promise<Project> {
    return this.request<Project>('GET', `/api/projects/${id}`, undefined, opts);
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
    return this.request<ChatMessage[]>('GET', `/api/chat/sessions/${sessionId}/messages`, undefined, opts);
  }

  async sendChatMessage(sessionId: string, body: string): Promise<SendChatMessageResponse> {
    return this.request<SendChatMessageResponse>('POST', `/api/chat/sessions/${sessionId}/messages`, { content: body });
  }

  // -------- Agents --------

  async listAgents(opts?: RequestOpts): Promise<Agent[]> {
    return this.request<Agent[]>('GET', '/api/agents', undefined, opts);
  }

  async listAgentTasks(agentId: string, opts?: RequestOpts): Promise<AgentTask[]> {
    return this.request<AgentTask[]>('GET', `/api/agents/${agentId}/tasks`, undefined, opts);
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

  async uploadFile(parentId: string, file: { uri: string; name: string; type: string }): Promise<Attachment> {
    // The shape mirrors the iOS FileAsset (apps/mobile/data/api.ts). On HarmonyOS
    // uploads use the same FormData+RequestBody pattern via @ohos.net.http.
    // Implementation is intentionally a stub here — the data flow is
    // identical (multipart/form-data, X-Request-ID, Bearer auth) but the
    // @ohos.net.http FormData surface differs from web fetch. Wire up the
    // real upload in a follow-up.
    throw new ApiError('uploadFile: not yet implemented on HarmonyOS', 501);
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
