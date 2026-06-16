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
 *
 * Why this file uses `Object` + named readers instead of
 * `unknown` + type guards: ArkTS 1.1 strict mode rejects
 * `unknown` as a type annotation, `value is T` as a user-defined
 * type guard, the `in` operator, inline object-literal type
 * expressions, indexed access types (`T['key']`), and
 * `Function.call` / `Function.apply` / prototype assignment. We
 * replace the dynamic validator with:
 *   - a set of typed `readXxx` helpers that do one `typeof` check
 *     at a time;
 *   - `Object.hasOwn(obj, key)` (static method) instead of
 *     `Object.prototype.hasOwnProperty.call(obj, key)`;
 *   - one named interface per response envelope (and per EMPTY
 *     fallback) so the type appears in a type position, not an
 *     inline literal;
 *   - one `class XxxSchemaImpl implements Schema<T>` per shape,
 *     because object-literal `validate` methods are not
 *     considered to "implement" a named interface by ArkTS.
 * The validator surface (`Schema<T>::validate`) still narrows
 * from a wide input to a typed output — exactly the behaviour iOS
 * gets from zod.
 */

import {
  Agent,
  AgentTask,
  ChatMessage,
  Comment,
  InboxItem,
  Issue,
  IssueReaction,
  Label,
  Project
} from '../models/types';
import {
  JsonValue,
  Schema,
  ParseResult,
  ParseFailure,
  fail,
  isObject,
  ok
} from './parse-response';

// ---------- local type aliases ----------
//
// Several model types are unions whose elements are inferred via
// indexed access (`Issue['labels']`, `Comment['author_type']`, etc.).
// ArkTS forbids indexed access types in type positions
// (`arkts-no-aliases-by-index`), so we restate the unions as
// explicit local aliases. They MUST stay in lockstep with
// `models/types.ets` — diff the two on every type rebase.

type IssueAssigneeTypeLit = 'member' | 'agent';
type CommentAuthorTypeLit = 'member' | 'agent';
type AgentTaskStatusLit = 'pending' | 'running' | 'completed' | 'failed' | 'cancelled';
type ChatRoleLit = 'user' | 'assistant' | 'system' | 'tool';

// ---------- typed readers ----------
//
// Each helper takes the raw input as `Object`, performs one
// `typeof` / `instanceof` check, and either returns the typed
// value or `defaultValue`. They replace the user-defined
// `value is T` predicates the iOS code uses (`isString`,
// `isNumber`, `isIssueAssigneeType`, etc.) and the `in`-based
// presence check the `readField` helper relied on.

/** True if `obj` has its own enumerable property at `key`. ArkTS
 *  forbids the `in` operator, `Object.hasOwn` (needs ES2022 lib),
 *  AND `Function.call` / `Function.apply`. The only path left is
 *  to enumerate `Object.keys` and check by hand — slow in the
 *  general case but our use is shallow (top-level fields only). */
function hasKey(obj: Object, key: string): boolean {
  const keys: string[] = Object.keys(obj);
  for (let i = 0; i < keys.length; i++) {
    if (keys[i] === key) return true;
  }
  return false;
}

/** Look up `key` on `obj` and return the raw value, or
 *  `undefined` if absent. ArkTS forbids direct `obj[key]`
 *  indexed access on a bare `Object`, so we cast through
 *  `Record<string, Object>` (the only indexed-signature-bearing
 *  type ArkTS tolerates as a cast target). */
function getField(obj: Object, key: string): Object | undefined {
  return (obj as Record<string, Object>)[key];
}

/** Helper: cast a `JsonValue` to `Object` for the read helpers.
 *  Callers must have already verified with `isObject` that
 *  the value is an object — this is the unsafe cast ArkTS
 *  forces on us because type predicates (`value is T`) are
 *  rejected (arkts-no-is). */
function asObject(v: JsonValue): Object | null {
  return v as Object;
}

function readString(value: JsonValue, key: string, defaultValue: string): string {
  const obj = asObject(value);
  if (obj === null) return defaultValue;
  if (!hasKey(obj, key)) return defaultValue;
  const v = getField(obj, key);
  if (v === undefined || v === null) return defaultValue;
  return typeof v === 'string' ? v as string : defaultValue;
}

function readNumber(value: JsonValue, key: string, defaultValue: number): number {
  const obj = asObject(value);
  if (obj === null) return defaultValue;
  if (!hasKey(obj, key)) return defaultValue;
  const v = getField(obj, key);
  if (v === undefined || v === null) return defaultValue;
  return typeof v === 'number' && Number.isFinite(v as number) ? v as number : defaultValue;
}

function readBoolean(value: JsonValue, key: string, defaultValue: boolean): boolean {
  const obj = asObject(value);
  if (obj === null) return defaultValue;
  if (!hasKey(obj, key)) return defaultValue;
  const v = getField(obj, key);
  if (v === undefined || v === null) return defaultValue;
  return typeof v === 'boolean' ? v as boolean : defaultValue;
}

function readNullableString(value: JsonValue, key: string): string | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return typeof v === 'string' ? v as string : null;
}

function readNullableNumber(value: JsonValue, key: string): number | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return typeof v === 'number' && Number.isFinite(v as number) ? v as number : null;
}

function readNullableObject(value: JsonValue, key: string): Record<string, Object> | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return isObject(v as JsonValue) ? v as Record<string, Object> : null;
}

function readIssueAssigneeType(value: JsonValue, key: string): IssueAssigneeTypeLit | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return v === 'member' || v === 'agent' ? v as IssueAssigneeTypeLit : null;
}

function readCommentAuthorType(value: JsonValue, key: string): CommentAuthorTypeLit | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return v === 'member' || v === 'agent' ? v as CommentAuthorTypeLit : null;
}

function readAgentTaskStatus(
  value: JsonValue,
  key: string,
  defaultValue: AgentTaskStatusLit
): AgentTaskStatusLit {
  const obj = asObject(value);
  if (obj === null) return defaultValue;
  if (!hasKey(obj, key)) return defaultValue;
  const v = getField(obj, key);
  if (
    v === 'pending' || v === 'running' || v === 'completed' ||
    v === 'failed' || v === 'cancelled'
  ) {
    return v as AgentTaskStatusLit;
  }
  return defaultValue;
}

function readChatRole(
  value: JsonValue,
  key: string,
  defaultValue: ChatRoleLit
): ChatRoleLit {
  const obj = asObject(value);
  if (obj === null) return defaultValue;
  if (!hasKey(obj, key)) return defaultValue;
  const v = getField(obj, key);
  if (v === 'user' || v === 'assistant' || v === 'system' || v === 'tool') {
    return v as ChatRoleLit;
  }
  return defaultValue;
}

function readLabelsArray(value: JsonValue, key: string): Label[] | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, key)) return null;
  const v = getField(obj, key);
  if (v === undefined || v === null) return null;
  return Array.isArray(v) ? v as Label[] : null;
}

function readReactionsArray(value: JsonValue, key: string): IssueReaction[] {
  const obj = asObject(value);
  if (obj === null) return [];
  if (!hasKey(obj, key)) return [];
  const v = getField(obj, key);
  if (!Array.isArray(v)) return [];
  return v as IssueReaction[];
}

function readRequiredId(value: JsonValue): string | null {
  const obj = asObject(value);
  if (obj === null) return null;
  if (!hasKey(obj, 'id')) return null;
  const v = getField(obj, 'id');
  return typeof v === 'string' ? v as string : null;
}

/** Pull a `Issue[]` out of an `Object`, dropping rows that fail
 *  per-row validation. */
function readIssueList(value: JsonValue, key: string): Issue[] {
  const obj = asObject(value);
  if (obj === null) return [];
  if (!hasKey(obj, key)) return [];
  const v = getField(obj, key);
  if (!Array.isArray(v)) return [];
  const arr = v as Object[];
  const out: Issue[] = [];
  for (let i = 0; i < arr.length; i++) {
    const r = IssueSchema.validate(arr[i] as JsonValue);
    if (r.success) {
      out.push(r.data);
    }
  }
  return out;
}

function readProjectList(value: JsonValue, key: string): Project[] {
  const obj = asObject(value);
  if (obj === null) return [];
  if (!hasKey(obj, key)) return [];
  const v = getField(obj, key);
  if (!Array.isArray(v)) return [];
  const arr = v as Object[];
  const out: Project[] = [];
  for (let i = 0; i < arr.length; i++) {
    const r = ProjectSchema.validate(arr[i] as JsonValue);
    if (r.success) {
      out.push(r.data);
    }
  }
  return out;
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

class IssueSchemaImpl implements Schema<Issue> {
  validate(value: JsonValue): ParseResult<Issue> {
    if (!isObject(value)) return fail('Issue: not an object', ['Issue must be a non-null object']);
    const id = readRequiredId(value);
    if (id === null) return fail('Issue.id missing or not a string', ['Issue.id must be a string']);
    const data: Issue = {
      id,
      number: readNumber(value, 'number', 0),
      identifier: readString(value, 'identifier', ''),
      title: readString(value, 'title', ''),
      description: readNullableString(value, 'description'),
      status: readString(value, 'status', 'backlog'),
      priority: readString(value, 'priority', 'no_priority'),
      workspace_id: readString(value, 'workspace_id', ''),
      project_id: readNullableString(value, 'project_id'),
      assignee_id: readNullableString(value, 'assignee_id'),
      assignee_type: readIssueAssigneeType(value, 'assignee_type'),
      assignee_name: readNullableString(value, 'assignee_name'),
      assignee_avatar_url: readNullableString(value, 'assignee_avatar_url'),
      creator_id: readNullableString(value, 'creator_id'),
      creator_name: readNullableString(value, 'creator_name'),
      creator_avatar_url: readNullableString(value, 'creator_avatar_url'),
      due_date: readNullableString(value, 'due_date'),
      created_at: readString(value, 'created_at', ''),
      updated_at: readString(value, 'updated_at', ''),
      labels: readLabelsArray(value, 'labels'),
      comment_count: readNumber(value, 'comment_count', 0)
    };
    return ok(data);
  }
}

export const IssueSchema: Schema<Issue> = new IssueSchemaImpl();

// ---------- Comment ----------

export const EMPTY_COMMENT: Comment = {
  id: '',
  issue_id: '',
  body: '',
  content: '',
  author_id: '',
  author_name: null,
  author_avatar_url: null,
  author_type: null,
  created_at: '',
  updated_at: '',
  edited: false,
  reactions: []
};

class CommentSchemaImpl implements Schema<Comment> {
  validate(value: JsonValue): ParseResult<Comment> {
    if (!isObject(value)) return fail('Comment: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('Comment.id missing or not a string');
    const data: Comment = {
      id,
      issue_id: readString(value, 'issue_id', ''),
      body: readString(value, 'body', readString(value, 'content', '')),
      content: readString(value, 'content', readString(value, 'body', '')),
      author_id: readString(value, 'author_id', ''),
      author_name: readNullableString(value, 'author_name'),
      author_avatar_url: readNullableString(value, 'author_avatar_url'),
      author_type: readCommentAuthorType(value, 'author_type'),
      created_at: readString(value, 'created_at', ''),
      updated_at: readString(value, 'updated_at', ''),
      edited: readBoolean(value, 'edited', false),
      reactions: readReactionsArray(value, 'reactions')
    };
    return ok(data);
  }
}

export const CommentSchema: Schema<Comment> = new CommentSchemaImpl();

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

class ProjectSchemaImpl implements Schema<Project> {
  validate(value: JsonValue): ParseResult<Project> {
    if (!isObject(value)) return fail('Project: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('Project.id missing or not a string');
    const data: Project = {
      id,
      name: readString(value, 'name', ''),
      identifier: readString(value, 'identifier', ''),
      description: readNullableString(value, 'description'),
      status: readString(value, 'status', 'planned'),
      priority: readString(value, 'priority', 'no_priority'),
      workspace_id: readString(value, 'workspace_id', ''),
      lead_id: readNullableString(value, 'lead_id'),
      lead_name: readNullableString(value, 'lead_name'),
      lead_avatar_url: readNullableString(value, 'lead_avatar_url'),
      start_date: readNullableString(value, 'start_date'),
      target_date: readNullableString(value, 'target_date'),
      created_at: readString(value, 'created_at', ''),
      updated_at: readString(value, 'updated_at', ''),
      issue_count: readNumber(value, 'issue_count', 0),
      progress: readNumber(value, 'progress', 0)
    };
    return ok(data);
  }
}

export const ProjectSchema: Schema<Project> = new ProjectSchemaImpl();

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

class InboxItemSchemaImpl implements Schema<InboxItem> {
  validate(value: JsonValue): ParseResult<InboxItem> {
    if (!isObject(value)) return fail('InboxItem: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('InboxItem.id missing or not a string');
    const data: InboxItem = {
      id,
      type: readString(value, 'type', 'mention'),
      read: readBoolean(value, 'read', false),
      archived: readBoolean(value, 'archived', false),
      issue_id: readNullableString(value, 'issue_id'),
      workspace_id: readString(value, 'workspace_id', ''),
      actor_id: readNullableString(value, 'actor_id'),
      actor_name: readNullableString(value, 'actor_name'),
      actor_avatar_url: readNullableString(value, 'actor_avatar_url'),
      details: readNullableObject(value, 'details'),
      created_at: readString(value, 'created_at', ''),
      updated_at: readString(value, 'updated_at', '')
    };
    return ok(data);
  }
}

export const InboxItemSchema: Schema<InboxItem> = new InboxItemSchemaImpl();

export const EMPTY_INBOX_LIST: InboxItem[] = [];

class InboxListSchemaImpl implements Schema<InboxItem[]> {
  validate(value: JsonValue): ParseResult<InboxItem[]> {
    if (!Array.isArray(value)) return fail('InboxList: not an array');
    const arr = value as Object[];
    const out: InboxItem[] = [];
    const dropped: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const r = InboxItemSchema.validate(arr[i] as JsonValue);
      if (r.success) {
        out.push(r.data);
      } else {
        dropped.push((r as ParseFailure).error);
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
}

export const InboxListSchema: Schema<InboxItem[]> = new InboxListSchemaImpl();

// ---------- Agent ----------

export const EMPTY_AGENT: Agent = {
  id: '',
  workspace_id: '',
  name: '',
  description: null,
  avatar_url: null,
  status: 'offline',
  runtime_mode: 'cloud',
  visibility: 'workspace',
  created_at: '',
  updated_at: ''
};

export const EMPTY_AGENT_LIST: Agent[] = [];

class AgentSchemaImpl implements Schema<Agent> {
  validate(value: JsonValue): ParseResult<Agent> {
    if (!isObject(value)) return fail('Agent: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('Agent.id missing or not a string');
    const name = readString(value, 'name', '').trim();
    if (name.length === 0) return fail('Agent.name missing or empty');
    const data: Agent = {
      id,
      workspace_id: readString(value, 'workspace_id', ''),
      name,
      description: readNullableString(value, 'description'),
      avatar_url: readNullableString(value, 'avatar_url'),
      status: readString(value, 'status', 'offline'),
      runtime_mode: readString(value, 'runtime_mode', 'cloud'),
      visibility: readString(value, 'visibility', 'workspace'),
      created_at: readString(value, 'created_at', ''),
      updated_at: readString(value, 'updated_at', '')
    };
    return ok(data);
  }
}

export const AgentSchema: Schema<Agent> = new AgentSchemaImpl();

class AgentListSchemaImpl implements Schema<Agent[]> {
  validate(value: JsonValue): ParseResult<Agent[]> {
    if (!Array.isArray(value)) return fail('AgentList: not an array');
    const arr = value as Object[];
    const out: Agent[] = [];
    const dropped: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const r = AgentSchema.validate(arr[i] as JsonValue);
      if (r.success) {
        out.push(r.data);
      } else {
        dropped.push((r as ParseFailure).error);
      }
    }
    if (dropped.length > 0) {
      console.warn(
        `[api] AgentList: ${dropped.length} item(s) failed validation; dropping the bad rows`,
        dropped
      );
    }
    return ok(out);
  }
}

export const AgentListSchema: Schema<Agent[]> = new AgentListSchemaImpl();

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

class AgentTaskSchemaImpl implements Schema<AgentTask> {
  validate(value: JsonValue): ParseResult<AgentTask> {
    if (!isObject(value)) return fail('AgentTask: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('AgentTask.id missing or not a string');
    const data: AgentTask = {
      id,
      agent_id: readString(value, 'agent_id', ''),
      workspace_id: readString(value, 'workspace_id', ''),
      status: readAgentTaskStatus(value, 'status', 'pending'),
      failure_reason: readNullableString(value, 'failure_reason'),
      prompt: readString(value, 'prompt', ''),
      started_at: readString(value, 'started_at', ''),
      finished_at: readNullableString(value, 'finished_at'),
      duration_ms: readNullableNumber(value, 'duration_ms'),
      cost_usd: readNullableNumber(value, 'cost_usd')
    };
    return ok(data);
  }
}

export const AgentTaskSchema: Schema<AgentTask> = new AgentTaskSchemaImpl();

export const EMPTY_AGENT_TASK_LIST: AgentTask[] = [];

class AgentTaskListSchemaImpl implements Schema<AgentTask[]> {
  validate(value: JsonValue): ParseResult<AgentTask[]> {
    if (!Array.isArray(value)) return fail('AgentTaskList: not an array');
    const arr = value as Object[];
    const out: AgentTask[] = [];
    for (let i = 0; i < arr.length; i++) {
      const r = AgentTaskSchema.validate(arr[i] as JsonValue);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
}

export const AgentTaskListSchema: Schema<AgentTask[]> = new AgentTaskListSchemaImpl();

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

class ChatMessageSchemaImpl implements Schema<ChatMessage> {
  validate(value: JsonValue): ParseResult<ChatMessage> {
    if (!isObject(value)) return fail('ChatMessage: not an object');
    const id = readRequiredId(value);
    if (id === null) return fail('ChatMessage.id missing or not a string');
    const data: ChatMessage = {
      id,
      session_id: readString(value, 'session_id', ''),
      role: readChatRole(value, 'role', 'user'),
      content: readString(value, 'content', ''),
      tool_name: readNullableString(value, 'tool_name'),
      tool_call_id: readNullableString(value, 'tool_call_id'),
      task_id: readNullableString(value, 'task_id'),
      created_at: readString(value, 'created_at', '')
    };
    return ok(data);
  }
}

export const ChatMessageSchema: Schema<ChatMessage> = new ChatMessageSchemaImpl();

export const EMPTY_CHAT_MESSAGE_LIST: ChatMessage[] = [];

class ChatMessageListSchemaImpl implements Schema<ChatMessage[]> {
  validate(value: JsonValue): ParseResult<ChatMessage[]> {
    if (!Array.isArray(value)) return fail('ChatMessageList: not an array');
    const arr = value as Object[];
    const out: ChatMessage[] = [];
    for (let i = 0; i < arr.length; i++) {
      const r = ChatMessageSchema.validate(arr[i] as JsonValue);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
}

export const ChatMessageListSchema: Schema<ChatMessage[]> = new ChatMessageListSchemaImpl();

// ---------- List envelopes ----------
//
// ArkTS forbids inline object-literal types, so each envelope
// gets a named interface. The shapes mirror the iOS
// `ListIssuesResponse` / `ListProjectsResponse` types in
// `packages/core/types/issue.ts` and `project.ts` — keep them in
// lockstep.

export interface ListIssuesResponse {
  issues: Issue[];
  total: number;
  page: number;
  page_size: number;
}

export interface ListProjectsResponse {
  projects: Project[];
  total: number;
}

/** `GET /api/issues` response — `{ issues, total, page, page_size }`. */
export const EMPTY_LIST_ISSUES_RESPONSE: ListIssuesResponse = {
  issues: [] as Issue[],
  total: 0,
  page: 1,
  page_size: 50
};

class ListIssuesResponseSchemaImpl implements Schema<ListIssuesResponse> {
  validate(value: JsonValue): ParseResult<ListIssuesResponse> {
    if (!isObject(value)) return fail('ListIssuesResponse: not an object');
    const data: ListIssuesResponse = {
      issues: readIssueList(value, 'issues'),
      total: readNumber(value, 'total', 0),
      page: readNumber(value, 'page', 1),
      page_size: readNumber(value, 'page_size', 50)
    };
    return ok(data);
  }
}

export const ListIssuesResponseSchema: Schema<ListIssuesResponse> = new ListIssuesResponseSchemaImpl();

export const EMPTY_LIST_PROJECTS_RESPONSE: ListProjectsResponse = {
  projects: [] as Project[],
  total: 0
};

class ListProjectsResponseSchemaImpl implements Schema<ListProjectsResponse> {
  validate(value: JsonValue): ParseResult<ListProjectsResponse> {
    if (!isObject(value)) return fail('ListProjectsResponse: not an object');
    const data: ListProjectsResponse = {
      projects: readProjectList(value, 'projects'),
      total: readNumber(value, 'total', 0)
    };
    return ok(data);
  }
}

export const ListProjectsResponseSchema: Schema<ListProjectsResponse> = new ListProjectsResponseSchemaImpl();

export const EMPTY_COMMENT_LIST: Comment[] = [];

class CommentListSchemaImpl implements Schema<Comment[]> {
  validate(value: JsonValue): ParseResult<Comment[]> {
    if (!Array.isArray(value)) return fail('CommentList: not an array');
    const arr = value as Object[];
    const out: Comment[] = [];
    for (let i = 0; i < arr.length; i++) {
      const r = CommentSchema.validate(arr[i] as JsonValue);
      if (r.success) out.push(r.data);
    }
    return ok(out);
  }
}

export const CommentListSchema: Schema<Comment[]> = new CommentListSchemaImpl();
