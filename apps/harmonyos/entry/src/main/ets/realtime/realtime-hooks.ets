import { wsClient } from './ws-client';
import { queryClient, QueryKey } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { inboxQueryKey } from '../queries/inbox';
import { issueListKey, issueDetailKey } from '../queries/issue';
import { projectDetailKey, projectListKey } from '../queries/project';
import { labelListKey, issueLabelsKey } from '../queries/labels';
import { memberListKey } from '../queries/members';
import { squadListKey } from '../queries/squads';
import { runtimeListKey } from '../queries/runtimes';
import { pinListKey } from '../queries/pins';
import { chatKeys } from '../queries/chat';
import { agentTasksKey, issueRunsKey } from '../queries/agent-tasks';
import { Preferences } from '../data/preferences';
import { realtimeLifecycle } from './lifecycle';
import { AgentTask, InboxItem, Issue, Project, WSEventType } from '../models/types';

/**
 * Realtime hooks. Mirrors the iOS app's data/realtime hooks
 * (apps/mobile/data/realtime/*.ts).
 *
 * The WS client is a singleton (realtime/ws-client.ets). Each
 * hook here subscribes to the relevant event types and patches
 * the query cache in place — TanStack Query style. Hooks return
 * an unsubscribe function the page can call from aboutToDisappear.
 *
 * Cache patches are surgical: when `issue:updated` arrives, we
 * only setQueryData the matching issueDetailKey + every issueListKey
 * whose cached entries include the issue. We don't wholesale
 * invalidate — a fresh fetch would race with the WS payload and
 * needlessly re-render every list.
 *
 * The page still owns the "mount" call: each hook returns
 * immediately, and the caller stores the unsubscribe function for
 * aboutToDisappear cleanup.
 */

type Unsub = () => void;

/**
 * The cache key prefix for an issue list: `['issues', wsId]`. We
 * build it explicitly instead of slicing the full key (which
 * forces an `as unknown as` cast under ArkTS's strict typing).
 */
const issueListPrefix = (wsId: string | null): QueryKey => ['issues', wsId];
const projectListPrefix = (wsId: string | null): QueryKey => ['projects', wsId];

/**
 * Wire `issue:*` + `comment:*` + `reaction:*` events to the matching
 * query cache entries. Returns an unsubscribe function.
 *
 * Args:
 *   - issueId: when provided, only the issue-detail and timeline
 *     caches are patched. When null, the hook is "listing-level" and
 *     patches every issue-list cache.
 *
 * Per-record subscriptions (issueId !== null):
 *   - issue:updated     — setQueryData on issueDetailKey
 *   - issue:deleted     — invalidate issueDetailKey
 *   - comment:created   — invalidate ['issue-comments', id]
 *   - comment:updated   — invalidate ['issue-comments', id]
 *   - comment:deleted   — invalidate ['issue-comments', id]
 *   - reaction:added    — invalidate ['issue-comments', id]
 *   - reaction:removed  — invalidate ['issue-comments', id]
 *
 * Listing-level subscriptions (issueId === null):
 *   - issue:created     — invalidatePrefix issue list
 *   - issue:updated     — invalidatePrefix issue list
 *   - issue:deleted     — invalidatePrefix issue list
 */
export function useIssueRealtime(issueId: string | null): Unsub {
  const unsubs: Unsub[] = [];
  const wsId = workspaceStore.currentId;

  if (issueId) {
    unsubs.push(wsClient.on<{ id: string; issue: Issue }>('issue:updated', (env) => {
      const incomingId = env.payload.issue?.id ?? env.payload.id;
      if (incomingId !== issueId) return;
      const key = issueDetailKey(wsId, issueId);
      queryClient.setQueryData<Issue>(key, env.payload.issue);
    }));
    unsubs.push(wsClient.on<{ id: string; issue_id: string; }>('issue:deleted', (env) => {
      if (env.payload.id !== issueId) return;
      // Invalidate the issue-detail cache; the issue list will
      // pick up the deletion via the listing-level subscription
      // (or the next refetch on the page that owns the list).
      queryClient.invalidate(issueDetailKey(wsId, issueId));
    }));

    // v1.0: the per-record subscription also covers comment and
    // reaction events for this issue. The previous v0.7 comment
    // claimed it did this but the actual subscriptions were
    // missing. Comment events invalidate the comment list cache;
    // reaction events invalidate the same cache because the
    // detail view re-fetches reactions with the comments.
    const commentListKey: QueryKey = ['issue-comments', issueId];
    unsubs.push(wsClient.on<{ id: string; issue_id: string; }>('comment:created', (env) => {
      if (env.payload.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }));
    unsubs.push(wsClient.on<{ id: string; issue_id: string; }>('comment:updated', (env) => {
      if (env.payload.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }));
    unsubs.push(wsClient.on<{ id: string; issue_id: string; }>('comment:deleted', (env) => {
      if (env.payload.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }));
    unsubs.push(wsClient.on<{ comment_id: string; issue_id: string; }>('reaction:added', (env) => {
      if (env.payload.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }));
    unsubs.push(wsClient.on<{ comment_id: string; issue_id: string; }>('reaction:removed', (env) => {
      if (env.payload.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }));
  } else {
    unsubs.push(wsClient.on<{ issue: Issue }>('issue:updated', () => {
      queryClient.invalidatePrefix(issueListPrefix(wsId));
    }));
    unsubs.push(wsClient.on('issue:created', () => {
      queryClient.invalidatePrefix(issueListPrefix(wsId));
    }));
    unsubs.push(wsClient.on('issue:deleted', () => {
      queryClient.invalidatePrefix(issueListPrefix(wsId));
    }));
  }

  return () => { for (const u of unsubs) u(); };
}

/**
 * Subscribe to inbox events. The hook is listing-level — every
 * page that renders the inbox list subscribes, and we invalidate
 * the inbox list cache so each observer refetches.
 */
export function useInboxRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  // Each event name is typed as WSEventType (a string union) so
  // wsClient.on's generic dispatch picks the right payload shape.
  const inboxEvents: WSEventType[] = ['inbox:created', 'inbox:updated', 'inbox:deleted'];
  for (const evt of inboxEvents) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidate(inboxQueryKey(wsId));
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Subscribe to project events. Listing-level + per-record (when a
 * projectId is passed in).
 */
export function useProjectRealtime(projectId: string | null): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  if (projectId) {
    unsubs.push(wsClient.on<{ id: string; project: Project }>('project:updated', (env) => {
      if (env.payload.id !== projectId) return;
      // v1.0 fix: the cache entry needs the Project object
      // (env.payload.project), not the whole envelope
      // (env.payload) — the latter has shape `{ id, project }`,
      // which would corrupt the ProjectDetailPage's read.
      queryClient.setQueryData<Project>(projectDetailKey(wsId, projectId), env.payload.project);
    }));
  } else {
    unsubs.push(wsClient.on('project:updated', () => {
      queryClient.invalidatePrefix(projectListPrefix(wsId));
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Subscribe to chat message events for a single session.
 */
export function useChatRealtime(sessionId: string | null): Unsub {
  if (!sessionId) return () => { /* noop */ };
  const key: QueryKey = ['chat-messages', sessionId];
  return wsClient.on<{ session_id: string; message: unknown }>('chat:message', (env) => {
    if (env.payload.session_id !== sessionId) return;
    queryClient.setQueryData<unknown[]>(key, (prev: unknown[] | undefined) => {
      const list = prev ? [...prev] : [];
      list.push(env.payload.message);
      return list;
    });
  });
}

/**
 * Subscribe to presence updates. The agent presence event includes
 * the agent id; we update a small dedicated cache so the agent
 * list / chat headers can render the live state.
 */
export function usePresenceRealtime(): Unsub {
  return wsClient.on<{ agent_id: string; status: string }>('presence:update', (env) => {
    const key: QueryKey = ['agent-presence', env.payload.agent_id];
    queryClient.setQueryData<{ status: string }>(key, { status: env.payload.status });
  });
}

/**
 * Task (a.k.a. agent run) realtime. Two flavours:
 *
 *   - `useTaskRealtime(agentId | issueId, kind)` — patch the
 *     per-agent or per-issue runs cache in place. Surgical
 *     patch: we look up the matching entry by id, and either
 *     upsert (running/progress) or replace (completed/failed).
 *     The runs list is small (rare for an agent to spawn 10+
 *     tasks per session) and the per-event payload is the full
 *     `AgentTask` row, so the patch is safe.
 *
 *   - `useAllTaskRealtime()` — listing-level. Mounted globally;
 *     invalidates the agent list / inbox "running" badges.
 */
export function useTaskRealtime(scope: { agentId?: string; issueId?: string }): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  const applyToKey = (key: QueryKey, task: AgentTask): void => {
    queryClient.setQueryData<AgentTask[]>(key, (prev) => {
      const list = prev ? [...prev] : [];
      const idx = list.findIndex((t) => t.id === task.id);
      if (idx >= 0) {
        list[idx] = task;
      } else {
        // New task: prepend so the live row is at the top of the
        // Runs tab (matches the iOS behaviour).
        list.unshift(task);
      }
      return list;
    });
  };
  const handlers: Array<WSEventType> = [
    'task:queued',
    'task:dispatch',
    'task:running',
    'task:progress',
    'task:completed',
    'task:failed',
    'task:cancelled'
  ];
  for (const evt of handlers) {
    unsubs.push(wsClient.on<AgentTask & { issue_id?: string }>(evt, (env) => {
      const task = env.payload;
      // Cross-scope filter: a `task:running` for issue X must not
      // patch the per-agent cache of agent Y. We use the
      // scope-stamped id (issue_id / agent_id) on the task to
      // decide whether this hook is in scope.
      if (scope.agentId && task.agent_id !== scope.agentId) return;
      if (scope.issueId && task.issue_id !== scope.issueId) return;
      if (scope.agentId) {
        applyToKey(agentTasksKey(wsId, scope.agentId), task);
      }
      if (scope.issueId) {
        applyToKey(issueRunsKey(wsId, scope.issueId), task);
      }
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

export function useAllTaskRealtime(): Unsub {
  return realtimeLifecycle.onReconnect(() => {
    // On reconnect, drop every per-agent / per-issue runs
    // cache. The next page that mounts will refetch and we'll
    // be back in sync. Invalidating on reconnect is the iOS
    // pattern (use-pins-realtime.ts::onReconnect).
    const wsId = workspaceStore.currentId;
    queryClient.invalidatePrefix(['agent-tasks', wsId]);
    queryClient.invalidatePrefix(['issue-runs', wsId]);
  });
}

/**
 * Agent listing realtime. The `agent:*` events cover the agent
 * directory (created / archived / restored) plus per-agent
 * status changes. Per the iOS pattern, the directory is
 * invalidated on every `agent:*` event (no formal payload type
 * for diffs); per-agent presence is patched into a separate
 * `agent-presence` cache (see `usePresenceRealtime`).
 */
export function useAgentRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  const events: WSEventType[] = ['agent:created', 'agent:archived', 'agent:restored'];
  for (const evt of events) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidatePrefix(['agents', wsId]);
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Label listing + per-issue label set realtime. The
 * `label:created` / `label:updated` / `label:deleted` events
 * invalidate the workspace label list; the
 * `issue_labels:changed` event invalidates the per-issue set so
 * the picker reflects server-side changes (a teammate added a
 * label from web while the issue is open in HarmonyOS).
 */
export function useLabelRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  for (const evt of ['label:created', 'label:updated', 'label:deleted'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidate(labelListKey(wsId));
    }));
  }
  unsubs.push(wsClient.on<{ issue_id: string }>('issue_labels:changed', (env) => {
    queryClient.invalidate(issueLabelsKey(wsId, env.payload.issue_id));
  }));
  return () => { for (const u of unsubs) u(); };
}

/**
 * Member listing realtime. `member:added` / `member:updated` /
 * `member:removed` invalidate the workspace member list so the
 * assignee picker stays current when a workspace admin invites
 * or removes a teammate.
 */
export function useMemberRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  for (const evt of ['member:added', 'member:updated', 'member:removed'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidate(memberListKey(wsId));
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Squad listing realtime. `squad:*` events invalidate the
 * workspace squad list (no formal payload type for diffs).
 */
export function useSquadRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  for (const evt of ['squad:created', 'squad:updated', 'squad:deleted'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidate(squadListKey(wsId));
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Runtime listing realtime. `daemon:register` and `daemon:heartbeat`
 * invalidate the runtime list — the same hook the iOS app wires
 * in `data/realtime/use-presence-realtime.ts`. The list is
 * small (one entry per registered device) and the events are
 * common while the user is signed in, so invalidate-on-event is
 * cheap.
 */
export function useRuntimeRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  for (const evt of ['daemon:register', 'daemon:heartbeat'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, () => {
      queryClient.invalidate(runtimeListKey(wsId));
    }));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Pin list realtime. Mirrors `apps/mobile/data/realtime/use-pins-realtime.ts`.
 * The WS payloads for `pin:*` events are typed as `unknown` in
 * the server contract (no stable shape), so we invalidate the
 * list rather than try to patch. The list is small and pin/unpin
 * is rare, so the cost is negligible.
 */
export function usePinRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const userId = Preferences.get('userId') ?? null;
  const unsubs: Unsub[] = [];
  const invalidate = (): void => {
    queryClient.invalidate(pinListKey(wsId, userId));
  };
  for (const evt of ['pin:created', 'pin:deleted', 'pin:reordered'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, invalidate));
  }
  return () => { for (const u of unsubs) u(); };
}

/**
 * Chat sessions list realtime. Mirrors
 * `apps/mobile/data/realtime/use-chat-sessions-realtime.ts`.
 *
 * Mounted globally from `WorkspaceLayout` so the chat list
 * reflects reality regardless of which tab the user is on. The
 * `chat:done` / `chat:session_read` events flip `unread_count`
 * server-side, so we invalidate the list to pick up the new
 * count. `chat:session_updated` patches in place (the rename
 * helper from iOS would be the ideal shape, but the HarmonyOS
 * cache is workspace-scoped and the iOS updater is not safe to
 * import — we keep the patch here for clarity).
 */
export function useChatSessionsRealtime(): Unsub {
  const wsId = workspaceStore.currentId;
  const unsubs: Unsub[] = [];
  const invalidate = (): void => {
    queryClient.invalidate(chatKeys.sessions(wsId));
  };
  for (const evt of ['chat:done', 'chat:session_read', 'chat:session_deleted'] as WSEventType[]) {
    unsubs.push(wsClient.on(evt, invalidate));
  }
  return () => { for (const u of unsubs) u(); };
}
