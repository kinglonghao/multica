/**
 * Multica shared type definitions — mirrored from packages/core/types/
 * for the HarmonyOS client.
 *
 * The iOS client imports these via `import type` from `@multica/core/types`
 * (see apps/mobile/CLAUDE.md "What mobile may import from packages/"). The
 * HarmonyOS build does not have access to that package — its compiler is
 * the standalone ArkTS toolchain, not the workspace — so we mirror the
 * shape into this file and document the source of truth at the top.
 *
 * RULES for keeping this file in sync with packages/core/types/:
 * 1. Add new fields here the same day they land upstream.
 * 2. Never invent a field that's not in upstream — the server contract is
 *    the source of truth and a phantom field will silently fall through
 *    parseWithFallback as `undefined`.
 * 3. When in doubt, fetch the latest @multica/core/types/<domain>.ts
 *    from main and diff line by line.
 */

export type IssueStatus = 'backlog' | 'todo' | 'in_progress' | 'in_review' | 'done' | 'cancelled' | string;
export type IssuePriority = 'no_priority' | 'urgent' | 'high' | 'medium' | 'low' | string;
export type IssueAssigneeType = 'member' | 'agent' | null;
export type InboxType = 'mention' | 'assignment' | 'status' | 'comment' | 'review_request' | string;
export type ProjectStatus = 'planned' | 'in_progress' | 'paused' | 'completed' | 'cancelled' | string;
export type ProjectPriority = 'no_priority' | 'urgent' | 'high' | 'medium' | 'low' | string;
export type AgentStatus = 'online' | 'busy' | 'offline' | string;
export type AgentRuntimeMode = 'cloud' | 'local' | string;
export type AgentVisibility = 'private' | 'workspace' | 'global' | string;
export type TaskFailureReason = 'timeout' | 'auth' | 'rate_limit' | 'crash' | 'user_abort' | 'unknown' | string;

export interface User {
  id: string;
  email: string;
  display_name?: string | null;
  avatar_url?: string | null;
  username?: string | null;
}

export interface Workspace {
  id: string;
  slug: string;
  name: string;
  avatar_url?: string | null;
  role?: string | null;
}

export interface Member {
  user_id: string;
  workspace_id: string;
  role: 'owner' | 'admin' | 'member' | 'guest';
  user?: User;
}

export interface MemberWithUser extends Member {
  user: User;
}

export interface Issue {
  id: string;
  number: number;
  identifier: string; // e.g. "MUL-123"
  title: string;
  description?: string | null;
  status: IssueStatus;
  priority: IssuePriority;
  workspace_id: string;
  project_id?: string | null;
  assignee_id?: string | null;
  assignee_type?: IssueAssigneeType;
  assignee_name?: string | null;
  assignee_avatar_url?: string | null;
  creator_id?: string | null;
  creator_name?: string | null;
  creator_avatar_url?: string | null;
  due_date?: string | null;
  created_at: string;
  updated_at: string;
  labels?: Label[] | null;
  comment_count?: number;
}

export interface CreateIssueRequest {
  title: string;
  description?: string;
  status?: IssueStatus;
  priority?: IssuePriority;
  project_id?: string | null;
  assignee_id?: string | null;
  assignee_type?: IssueAssigneeType;
  due_date?: string | null;
  label_ids?: string[];
}

export interface UpdateIssueRequest {
  title?: string;
  description?: string;
  status?: IssueStatus;
  priority?: IssuePriority;
  project_id?: string | null;
  assignee_id?: string | null;
  assignee_type?: IssueAssigneeType;
  due_date?: string | null;
  label_ids?: string[];
}

export interface ListIssuesParams {
  status?: IssueStatus | IssueStatus[];
  priority?: IssuePriority | IssuePriority[];
  assignee_id?: string;
  project_id?: string;
  search?: string;
  page?: number;
  page_size?: number;
}

export interface ListIssuesResponse {
  issues: Issue[];
  total: number;
  page: number;
  page_size: number;
}

export interface InboxItem {
  id: string;
  type: InboxType;
  read: boolean;
  archived: boolean;
  issue_id?: string | null;
  workspace_id: string;
  actor_id?: string | null;
  actor_name?: string | null;
  actor_avatar_url?: string | null;
  details?: Record<string, unknown> | null;
  created_at: string;
  updated_at: string;
}

export interface Project {
  id: string;
  name: string;
  identifier: string; // e.g. "ENG"
  description?: string | null;
  status: ProjectStatus;
  priority: ProjectPriority;
  workspace_id: string;
  lead_id?: string | null;
  lead_name?: string | null;
  lead_avatar_url?: string | null;
  start_date?: string | null;
  target_date?: string | null;
  created_at: string;
  updated_at: string;
  issue_count?: number;
  progress?: number;
}

export interface CreateProjectRequest {
  name: string;
  identifier: string;
  description?: string;
  status?: ProjectStatus;
  priority?: ProjectPriority;
  lead_id?: string;
  start_date?: string | null;
  target_date?: string | null;
}

export interface UpdateProjectRequest {
  name?: string;
  description?: string;
  status?: ProjectStatus;
  priority?: ProjectPriority;
  lead_id?: string;
  start_date?: string | null;
  target_date?: string | null;
}

export interface ListProjectsResponse {
  projects: Project[];
  total: number;
}

export interface ProjectResource {
  id: string;
  project_id: string;
  name: string;
  url?: string | null;
  type: string;
  created_at: string;
}

export interface ListProjectResourcesResponse {
  resources: ProjectResource[];
  total: number;
}

export interface CreateProjectResourceRequest {
  name: string;
  url?: string;
  type: string;
}

export interface Label {
  id: string;
  name: string;
  color: string;
  workspace_id: string;
}

export interface CreateLabelRequest {
  name: string;
  color: string;
}

export interface ListLabelsResponse {
  labels: Label[];
  total: number;
}

export interface Comment {
  id: string;
  issue_id: string;
  body: string;
  author_id: string;
  author_name?: string | null;
  author_avatar_url?: string | null;
  author_type?: 'member' | 'agent' | null;
  created_at: string;
  updated_at: string;
  edited?: boolean;
  reactions?: IssueReaction[];
}

export interface TimelineEntry {
  id: string;
  type: 'comment' | 'activity' | 'system';
  issue_id: string;
  created_at: string;
  comment?: Comment | null;
  activity_type?: string | null;
  actor_id?: string | null;
  actor_name?: string | null;
  actor_avatar_url?: string | null;
  details?: Record<string, unknown> | null;
}

export interface IssueReaction {
  id: string;
  comment_id: string;
  emoji: string;
  user_id: string;
  user_name?: string | null;
  created_at: string;
}

export interface ChatSession {
  id: string;
  workspace_id: string;
  agent_id?: string | null;
  agent_name?: string | null;
  agent_avatar_url?: string | null;
  title?: string | null;
  last_message_at?: string | null;
  last_message_preview?: string | null;
  unread_count?: number;
  created_at: string;
  updated_at: string;
}

export interface ChatMessage {
  id: string;
  session_id: string;
  role: 'user' | 'assistant' | 'system' | 'tool';
  content: string;
  tool_name?: string | null;
  tool_call_id?: string | null;
  task_id?: string | null;
  created_at: string;
}

export interface ChatPendingTask {
  id: string;
  session_id: string;
  agent_id: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  tool_name?: string | null;
  started_at: string;
  finished_at?: string | null;
}

export interface SendChatMessageResponse {
  user_message: ChatMessage;
  assistant_message?: ChatMessage | null;
  pending_task?: ChatPendingTask | null;
}

export interface Agent {
  id: string;
  workspace_id: string;
  name: string;
  description?: string | null;
  avatar_url?: string | null;
  status: AgentStatus;
  runtime_mode: AgentRuntimeMode;
  visibility: AgentVisibility;
  created_at: string;
  updated_at: string;
}

export interface AgentTask {
  id: string;
  agent_id: string;
  workspace_id: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
  failure_reason?: TaskFailureReason | null;
  prompt: string;
  started_at: string;
  finished_at?: string | null;
  duration_ms?: number | null;
  cost_usd?: number | null;
}

export interface AgentActivityBucket {
  agent_id: string;
  agent_name: string;
  agent_avatar_url?: string | null;
  bucket_date: string; // YYYY-MM-DD
  run_count: number;
  status: 'completed' | 'failed' | 'running';
}

export interface RuntimeDevice {
  id: string;
  name: string;
  platform: string;
  online: boolean;
  last_seen_at?: string | null;
}

export interface Attachment {
  id: string;
  filename: string;
  content_type: string;
  size: number;
  url: string;
  thumbnail_url?: string | null;
  created_at: string;
}

export interface PinnedItem {
  id: string;
  type: 'issue' | 'project' | 'doc';
  workspace_id: string;
  position: number;
  item_id: string;
  item?: Issue | Project | null;
  created_at: string;
}

export interface ReorderPinsRequest {
  pinned_ids: string[];
}

export interface Squad {
  id: string;
  name: string;
  description?: string | null;
  workspace_id: string;
  created_at: string;
}

export interface NotificationPreference {
  channel: 'email' | 'push' | 'in_app';
  category: 'mentions' | 'assignments' | 'comments' | 'status_changes' | 'review_requests';
  enabled: boolean;
}

export interface NotificationPreferences {
  workspace_id: string;
  preferences: NotificationPreference[];
}

export interface NotificationPreferenceResponse {
  preferences: NotificationPreferences;
}

export interface SearchIssuesResponse {
  issues: Issue[];
  total: number;
}

export interface SearchProjectsResponse {
  projects: Project[];
  total: number;
}

export interface LoginResponse {
  token: string;
  user: User;
}

export interface IssueLabelsResponse {
  issue_id: string;
  labels: Label[];
}

/**
 * Realtime event names from packages/core/types/events.ts. The HarmonyOS
 * client subscribes via the same names as the iOS client — the server
 * speaks one WS protocol.
 *
 * The runtime registry that backs this union lives in
 * `lib/ws-events.ets::WSEventNames`. Both files are derived by hand
 * from `packages/core/types/events.ts::WSEventType` and must stay
 * in lockstep — `scripts/diff-harmonyos-types.ts` (CI + rebase gate)
 * fails if they drift.
 *
 * The trailing `| string` is intentional: a brand-new event name
 * emitted by a server we haven't mirrored yet is still accepted by
 * the validator (the protocol is the source of truth — we must not
 * brick existing clients when a server deploys a new event). The
 * registry's purpose is to *detect* the gap loudly via
 * `assertWSEventRegistry()` (see `realtime/ws-client.ets`), not to
 * *prevent* it.
 */
export type WSEventType =
  | 'issue:created'
  | 'issue:updated'
  | 'issue:deleted'
  | 'comment:created'
  | 'comment:updated'
  | 'comment:deleted'
  | 'comment:resolved'
  | 'comment:unresolved'
  | 'agent:status'
  | 'agent:created'
  | 'agent:archived'
  | 'agent:restored'
  | 'task:queued'
  | 'task:dispatch'
  | 'task:running'
  | 'task:waiting_local_directory'
  | 'task:progress'
  | 'task:completed'
  | 'task:failed'
  | 'task:message'
  | 'task:cancelled'
  | 'inbox:new'
  | 'inbox:read'
  | 'inbox:archived'
  | 'inbox:batch-read'
  | 'inbox:batch-archived'
  | 'workspace:updated'
  | 'workspace:deleted'
  | 'member:added'
  | 'member:updated'
  | 'member:removed'
  | 'daemon:heartbeat'
  | 'daemon:register'
  | 'skill:created'
  | 'skill:updated'
  | 'skill:deleted'
  | 'subscriber:added'
  | 'subscriber:removed'
  | 'activity:created'
  | 'reaction:added'
  | 'reaction:removed'
  | 'issue_reaction:added'
  | 'issue_reaction:removed'
  | 'chat:message'
  | 'chat:done'
  | 'chat:session_read'
  | 'chat:session_deleted'
  | 'chat:session_updated'
  | 'project:created'
  | 'project:updated'
  | 'project:deleted'
  | 'squad:created'
  | 'squad:updated'
  | 'squad:deleted'
  | 'label:created'
  | 'label:updated'
  | 'label:deleted'
  | 'issue_labels:changed'
  | 'issue_metadata:changed'
  | 'pin:created'
  | 'pin:deleted'
  | 'pin:reordered'
  | 'invitation:created'
  | 'invitation:accepted'
  | 'invitation:declined'
  | 'invitation:revoked'
  | 'github_installation:created'
  | 'github_installation:deleted'
  | 'pull_request:linked'
  | 'pull_request:updated'
  | 'pull_request:unlinked'
  | string;

export interface WSEnvelope<T = unknown> {
  event: WSEventType;
  payload: T;
  ts: string;
}
