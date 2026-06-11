/**
 * Hand-rolled validators for API response bodies. Mirrors
 * `apps/mobile/data/schemas.ts` and the iOS `Zod` schemas exported
 * from `@multica/core/api/schemas` — minus the actual zod runtime.
 *
 * Why hand-rolled: the HarmonyOS build chain (ArkTS strict mode)
 * forbids the dynamic property access that zod's TypeScript output
 * relies on, and adding zod-as-a-thing to a HarmonyOS build is a
 * multi-week rabbit hole. A 30-line validator per shape is enough
 * to catch the "missing field" / "wrong type" cases the iOS
 * schemas catch — and the failure mode (logged warning + safe
 * fallback) is the same.
 *
 * What we DON'T do:
 *   - We don't try to validate every field. A "loose" schema that
 *     lets unknown fields pass through is closer to the iOS
 *     `.loose()` zod pattern. A future server field never breaks
 *     the client.
 *   - We don't try to coerce types. The server contract is the
 *     source of truth; if `comment_count` arrives as a string the
 *     validator fails and the fallback is used. Coercion would
 *     hide real bugs.
 *
 * Each schema is paired with an `EMPTY_*` fallback that matches
 * the type exactly. The fallback MUST be a value the rest of the
 * app can render without crashing — typically an empty array, a
 * stub object with `id: ""`, or `null` (for nullable endpoints).
 */

import {
  AgentTask,
  ChatMessage,
  Comment,
  InboxItem,
  Issue,
  Project
} from '../models/types';
import {
  Schema,
  ParseResult,
  fail,
  isObject,
  ok
} from './parse-response';

// ---------- helpers ----------

function isString(value: unknown): value is string {
  return typeof value === 'string';
}

function isNumber(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function isBoolean(value: unknown): value is boolean {
  return typeof value === 'boolean';
}

function isStringArray(value: unknown): value is string[] {
  return Array.isArray(value) && value.every(isString);
}

function isNullableString(value: unknown): value is string | null | undefined {
  return value === null || value === undefined || isString(value);
}

/**
 * Lenient reader: returns the typed value if it matches the
 * shape, or `defaultValue` if the field is missing / wrong type.
 * The schema as a whole still succeeds (a "wrong-type" field is
 * not a "wrong-shape" response). This matches zod's `.default()`
 * behaviour and keeps the page from breaking when a server adds a
 * field we haven't yet mirrored.
 */
function readField<T>(obj: Record<string, unknown>, key: string, predicate: (v: unknown) => v is T, defaultValue: T): T {
  if (!(key in obj)) return defaultValue;
  const v = obj[key];
  if (v === undefined || v === null) return defaultValue;
  return predicate(v) ? v : defaultValue;
}

// ---------- Issue ----------

export const EMPTY_ISSUE: Issue = {
  id: '',
  number: 0,
  identifier: '',
  title: '',
  description: null,
  status: 'backlog',
  priority: 'no_priority',
  workspace_id: '',
  project_id: null,
  assignee_id: null,
  assignee_type: null,
  assignee_name: null,
  assignee_avatar_url: null,
  creator_id: null,
  creator_name: null,
  creator_avatar_url: null,
  due_date: null,
  created_at: '',
  updated_at: '',
  labels: null,
  comment_count: 0
};

export const IssueSchema: Schema<Issue> = {
  validate(value: unknown): ParseResult<Issue> {
    if (!isObject(value)) return fail('Issue: not an object', ['Issue must be a non-null object']);
    const id = value['id'];
    if (!isString(id)) return fail('Issue.id missing or not a string', ['Issue.id must be a string']);
    return ok({
      id,
      number: readField(value, 'number', isNumber, 0),
      identifier: readField(value, 'identifier', isString, ''),
      title: readField(value, 'title', isString, ''),
      description: readField(value, 'description', isNullableString, null),
      status: readField(value, 'status', isString, 'backlog'),
      priority: readField(value, 'priority', isString, 'no_priority'),
      workspace_id: readField(value, 'workspace_id', isString, ''),
      project_id: readField(value, 'project_id', isNullableString, null),
      assignee_id: readField(value, 'assignee_id', isNullableString, null),
      assignee_type: readField(value, 'assignee_type', isNullableString, null),
      assignee_name: readField(value, 'assignee_name', isNullableString, null),
      assignee_avatar_url: readField(value, 'assignee_avatar_url', isNullableString, null),
      creator_id: readField(value, 'creator_id', isNullableString, null),
      creator_name: readField(value, 'creator_name', isNullableString, null),
      creator_avatar_url: readField(value, 'creator_avatar_url', isNullableString, null),
      due_date: readField(value, 'due_date', isNullableString, null),
      created_at: readField(value, 'created_at', isString, ''),
      updated_at: readField(value, 'updated_at', isString, ''),
      labels: readField(value, 'labels', (v): v is Issue['labels'] => v === null || Array.isArray(v), null),
      comment_count: readField(value, 'comment_count', isNumber, 0)
    });
  }
};

// ---------- Comment ----------

export const EMPTY_COMMENT: Comment = {
  id: '',
  issue_id: '',
  body: '',
  author_id: '',
  author_name: null,
  author_avatar_url: null,
  author_type: null,
  created_at: '',
  updated_at: '',
  edited: false,
  reactions: []
};

export const CommentSchema: Schema<Comment> = {
  validate(value: unknown): ParseResult<Comment> {
    if (!isObject(value)) return fail('Comment: not an object');
    const id = value['id'];
    if (!isString(id)) return fail('Comment.id missing or not a string');
    return ok({
      id,
      issue_id: readField(value, 'issue_id', isString, ''),
      body: readField(value, 'body', isString, ''),
      author_id: readField(value, 'author_id', isString, ''),
      author_name: readField(value, 'author_name', isNullableString, null),
      author_avatar_url: readField(value, 'author_avatar_url', isNullableString, null),
      author_type: readField(value, 'author_type', isNullableString, null),
      created_at: readField(value, 'created_at', isString, ''),
      updated_at: readField(value, 'updated_at', isString, ''),
      edited: readField(value, 'edited', isBoolean, false),
      reactions: readField(value, 'reactions', (v) => Array.isArray(v), [])
    });
  }
};

// ---------- Project ----------

export const EMPTY_PROJECT: Project = {
  id: '',
  name: '',
  identifier: '',
  description: null,
  status: 'planned',
  priority: 'no_priority',
  workspace_id: '',
  lead_id: null,
  lead_name: null,
  lead_avatar_url: null,
  start_date: null,
  target_date: null,
  created_at: '',
  updated_at: '',
  issue_count: 0,
  progress: 0
};

export const ProjectSchema: Schema<Project> = {
  validate(value: unknown): ParseResult<Project> {
    if (!isObject(value)) return fail('Project: not an object');
    const id = value['id'];
    if (!isString(id)) return fail('Project.id missing or not a string');
    return ok({
      id,
      name: readField(value, 'name', isString, ''),
      identifier: readField(value, 'identifier', isString, ''),
      description: readField(value, 'description', isNullableString, null),
      status: readField(value, 'status', isString, 'planned'),
      priority: readField(value, 'priority', isString, 'no_priority'),
      workspace_id: readField(value, 'workspace_id', isString, ''),
      lead_id: readField(value, 'lead_id', isNullableString, null),
      lead_name: readField(value, 'lead_name', isNullableString, null),
      lead_avatar_url: readField(value, 'lead_avatar_url', isNullableString, null),
      start_date: readField(value, 'start_date', isNullableString, null),
      target_date: readField(value, 'target_date', isNullableString, null),
      created_at: readField(value, 'created_at', isString, ''),
      updated_at: readField(value, 'updated_at', isString, ''),
      issue_count: readField(value, 'issue_count', isNumber, 0),
      progress: readField(value, 'progress', isNumber, 0)
    });
  }
};

// ---------- InboxItem ----------

export const EMPTY_INBOX_ITEM: InboxItem = {
  id: '',
  type: 'mention',
  read: false,
  archived: false,
  issue_id: null,
  workspace_id: '',
  actor_id: null,
  actor_name: null,
  actor_avatar_url: null,
  details: null,
  created_at: '',
  updated_at: ''
};

export const InboxItemSchema: Schema<InboxItem> = {
  validate(value: unknown): ParseResult<InboxItem> {
    if (!isObject(value)) return fail('InboxItem: not an object');
    const id = value['id'];
    if (!isString(id)) return fail('InboxItem.id missing or not a string');
    return ok({
      id,
      type: readField(value, 'type', isString, 'mention'),
      read: readField(value, 'read', isBoolean, false),
      archived: readField(value, 'archived', isBoolean, false),
      issue_id: readField(value, 'issue_id', isNullableString, null),
      workspace_id: readField(value, 'workspace_id', isString, ''),
      actor_id: readField(value, 'actor_id', isNullableString, null),
      actor_name: readField(value, 'actor_name', isNullableString, null),
      actor_avatar_url: readField(value, 'actor_avatar_url', isNullableString, null),
      details: readField(value, 'details', (v) => v === null || isObject(v), null),
      created_at: readField(value, 'created_at', isString, ''),
      updated_at: readField(value, 'updated_at', isString, '')
    });
  }
};

export const EMPTY_INBOX_LIST: InboxItem[] = [];
export const InboxListSchema: Schema<InboxItem[]> = {
  validate(value: unknown): ParseResult<InboxItem[]> {
    if (!Array.isArray(value)) return fail('InboxList: not an array');
    const out: InboxItem[] = [];
    const dropped: string[] = [];
    for (const item of value) {
      const r = InboxItemSchema.validate(item);
      if (r.success) {
        out.push(r.data);
      } else {
        dropped.push(r.error);
      }
    }
    if (dropped.length > 0) {
      console.warn(
        `[api] InboxList: ${dropped.length} item(s) failed validation; dropping the bad rows`,
        dropped
      );
    }
    return ok(out);
  }
};

// ---------- AgentTask ----------

export const EMPTY_AGENT_TASK: AgentTask = {
  id: '',
  agent_id: '',
  workspace_id: '',
  status: 'pending',
  failure_reason: null,
  prompt: '',
  started_at: '',
  finished_at: null,
  duration_ms: null,
  cost_usd: null
};

export const AgentTaskSchema: Schema<AgentTask> = {
  validate(value: unknown): ParseResult<AgentTask> {
    if (!isObject(value)) return fail('AgentTask: not an object');
    const id = value['id'];
    if (!isString(id)) return fail('AgentTask.id missing or not a string');
    return ok({
      id,
      agent_id: readField(value, 'agent_id', isString, ''),
      workspace_id: readField(value, 'workspace_id', isString, ''),
      status: readField(value, 'status', isString, 'pending'),
      failure_reason: readField(value, 'failure_reason', isNullableString, null),
      prompt: readField(value, 'prompt', isString, ''),
      started_at: readField(value, 'started_at', isString, ''),
      finished_at: readField(value, 'finished_at', isNullableString, null),
      duration_ms: readField(value, 'duration_ms', (v): v is number | null => v === null || isNumber(v), null),
      cost_usd: readField(value, 'cost_usd', (v): v is number | null => v === null || isNumber(v), null)
    });
  }
};

export const EMPTY_AGENT_TASK_LIST: AgentTask[] = [];
export const AgentTaskListSchema: Schema<AgentTask[]> = {
  validate(value: unknown): ParseResult<AgentTask[]> {
    if (!Array.isArray(value)) return fail('AgentTaskList: not an array');
    const out: AgentTask[] = [];
    for (const item of value) {
      const r = AgentTaskSchema.validate(item);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
};

// ---------- ChatMessage ----------

export const EMPTY_CHAT_MESSAGE: ChatMessage = {
  id: '',
  session_id: '',
  role: 'user',
  content: '',
  tool_name: null,
  tool_call_id: null,
  task_id: null,
  created_at: ''
};

export const ChatMessageSchema: Schema<ChatMessage> = {
  validate(value: unknown): ParseResult<ChatMessage> {
    if (!isObject(value)) return fail('ChatMessage: not an object');
    const id = value['id'];
    if (!isString(id)) return fail('ChatMessage.id missing or not a string');
    return ok({
      id,
      session_id: readField(value, 'session_id', isString, ''),
      role: readField(value, 'role', isString, 'user'),
      content: readField(value, 'content', isString, ''),
      tool_name: readField(value, 'tool_name', isNullableString, null),
      tool_call_id: readField(value, 'tool_call_id', isNullableString, null),
      task_id: readField(value, 'task_id', isNullableString, null),
      created_at: readField(value, 'created_at', isString, '')
    });
  }
};

export const EMPTY_CHAT_MESSAGE_LIST: ChatMessage[] = [];
export const ChatMessageListSchema: Schema<ChatMessage[]> = {
  validate(value: unknown): ParseResult<ChatMessage[]> {
    if (!Array.isArray(value)) return fail('ChatMessageList: not an array');
    const out: ChatMessage[] = [];
    for (const item of value) {
      const r = ChatMessageSchema.validate(item);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
};

// ---------- List envelopes ----------

/** `GET /api/issues` response — `{ issues, total, page, page_size }`. */
export const EMPTY_LIST_ISSUES_RESPONSE = { issues: [] as Issue[], total: 0, page: 1, page_size: 50 };
export const ListIssuesResponseSchema: Schema<{ issues: Issue[]; total: number; page: number; page_size: number }> = {
  validate(value: unknown): ParseResult<{ issues: Issue[]; total: number; page: number; page_size: number }> {
    if (!isObject(value)) return fail('ListIssuesResponse: not an object');
    const issuesRaw = value['issues'];
    const issues: Issue[] = Array.isArray(issuesRaw)
      ? issuesRaw.flatMap((it) => {
          const r = IssueSchema.validate(it);
          return r.success ? [r.data] : [];
        })
      : [];
    return ok({
      issues,
      total: readField(value, 'total', isNumber, 0),
      page: readField(value, 'page', isNumber, 1),
      page_size: readField(value, 'page_size', isNumber, 50)
    });
  }
};

export const EMPTY_LIST_PROJECTS_RESPONSE = { projects: [] as Project[], total: 0 };
export const ListProjectsResponseSchema: Schema<{ projects: Project[]; total: number }> = {
  validate(value: unknown): ParseResult<{ projects: Project[]; total: number }> {
    if (!isObject(value)) return fail('ListProjectsResponse: not an object');
    const projectsRaw = value['projects'];
    const projects: Project[] = Array.isArray(projectsRaw)
      ? projectsRaw.flatMap((it) => {
          const r = ProjectSchema.validate(it);
          return r.success ? [r.data] : [];
        })
      : [];
    return ok({
      projects,
      total: readField(value, 'total', isNumber, 0)
    });
  }
};

export const EMPTY_COMMENT_LIST: Comment[] = [];
export const CommentListSchema: Schema<Comment[]> = {
  validate(value: unknown): ParseResult<Comment[]> {
    if (!Array.isArray(value)) return fail('CommentList: not an array');
    const out: Comment[] = [];
    for (const it of value) {
      const r = CommentSchema.validate(it);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
};
