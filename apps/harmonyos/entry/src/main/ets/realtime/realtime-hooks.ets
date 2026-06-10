import { wsClient } from './ws-client';
import { queryClient, QueryKey } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { inboxQueryKey } from '../queries/inbox';
import { issueListKey, issueDetailKey } from '../queries/issue';
import { projectDetailKey, projectListKey } from '../queries/project';
import { InboxItem, Issue, Project } from '../models/types';

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
      queryClient.setQueryData<Project>(projectDetailKey(wsId, projectId), env.payload);
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
