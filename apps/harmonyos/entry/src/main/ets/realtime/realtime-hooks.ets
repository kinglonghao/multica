import { wsClient, WSEnvelopeHandler } from './ws-client';
import { queryClient, QueryKey } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { inboxQueryKey } from '../queries/inbox';
import { issueDetailKey } from '../queries/issue';
import { projectDetailKey } from '../queries/project';
import {
  ChatMessage,
  ChatMessagePayload,
  InboxItem,
  Issue,
  IssueScopedPayload,
  IssueUpdatedPayload,
  PresencePayload,
  Project,
  ProjectUpdatedPayload,
  ReactionPayload,
  WSEnvelope,
  WSEventType
} from '../models/types';

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
    unsubs.push(wsClient.on('issue:updated', ((env: WSEnvelope<IssueUpdatedPayload>) => {
      const p = env.payload;
      const incomingId = p.issue?.id ?? p.id;
      if (incomingId !== issueId) return;
      const key = issueDetailKey(wsId, issueId);
      queryClient.setQueryData<Issue>(key, p.issue);
    }) as WSEnvelopeHandler));
    unsubs.push(wsClient.on('issue:deleted', ((env: WSEnvelope<IssueScopedPayload>) => {
      const p = env.payload;
      if (p.id !== issueId) return;
      // Invalidate the issue-detail cache; the issue list will
      // pick up the deletion via the listing-level subscription
      // (or the next refetch on the page that owns the list).
      queryClient.invalidate(issueDetailKey(wsId, issueId));
    }) as WSEnvelopeHandler));

    // v1.0: the per-record subscription also covers comment and
    // reaction events for this issue. The previous v0.7 comment
    // claimed it did this but the actual subscriptions were
    // missing. Comment events invalidate the comment list cache;
    // reaction events invalidate the same cache because the
    // detail view re-fetches reactions with the comments.
    const commentListKey: QueryKey = ['issue-comments', issueId];
    unsubs.push(wsClient.on('comment:created', ((env: WSEnvelope<IssueScopedPayload>) => {
      const p = env.payload;
      if (p.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }) as WSEnvelopeHandler));
    unsubs.push(wsClient.on('comment:updated', ((env: WSEnvelope<IssueScopedPayload>) => {
      const p = env.payload;
      if (p.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }) as WSEnvelopeHandler));
    unsubs.push(wsClient.on('comment:deleted', ((env: WSEnvelope<IssueScopedPayload>) => {
      const p = env.payload;
      if (p.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }) as WSEnvelopeHandler));
    unsubs.push(wsClient.on('reaction:added', ((env: WSEnvelope<ReactionPayload>) => {
      const p = env.payload;
      if (p.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }) as WSEnvelopeHandler));
    unsubs.push(wsClient.on('reaction:removed', ((env: WSEnvelope<ReactionPayload>) => {
      const p = env.payload;
      if (p.issue_id !== issueId) return;
      queryClient.invalidate(commentListKey);
    }) as WSEnvelopeHandler));
  } else {
    unsubs.push(wsClient.on('issue:updated', () => {
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
  // Parity fix: these names mirror the iOS inbox realtime hook
  // (apps/mobile/data/realtime/use-inbox-realtime.ts). The earlier
  // code invented inbox:created/updated/deleted which are NOT in the
  // upstream protocol — dispatch() would have silently dropped every
  // one. These five are the real server events. Handlers ignore the
  // payload (invalidate-only) so the wide fallback overload is fine.
  const inboxEvents: WSEventType[] = [
    'inbox:new', 'inbox:read', 'inbox:archived',
    'inbox:batch-read', 'inbox:batch-archived'
  ];
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
    unsubs.push(wsClient.on('project:updated', ((env: WSEnvelope<ProjectUpdatedPayload>) => {
      const p = env.payload;
      if (p.id !== projectId) return;
      // v1.0 fix: the cache entry needs the Project object
      // (env.payload.project), not the whole envelope
      // (env.payload) — the latter has shape `{ id, project }`,
      // which would corrupt the ProjectDetailPage's read.
      queryClient.setQueryData<Project>(projectDetailKey(wsId, projectId), p.project);
    }) as WSEnvelopeHandler));
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
  return wsClient.on('chat:message', ((env: WSEnvelope<ChatMessagePayload>) => {
    const p = env.payload;
    if (p.session_id !== sessionId) return;
    queryClient.setQueryData<ChatMessage[]>(key, (prev: ChatMessage[] | undefined) => {
      const list = prev ? [...prev] : [];
      list.push(p.message);
      return list;
    });
  }) as WSEnvelopeHandler);
}

/**
 * Subscribe to presence updates. The agent presence event includes
 * the agent id; we update a small dedicated cache so the agent
 * list / chat headers can render the live state.
 */
export function usePresenceRealtime(): Unsub {
  return wsClient.on('agent:status', ((env: WSEnvelope<PresencePayload>) => {
    const p = env.payload;
    const key: QueryKey = ['agent-presence', p.agent_id];
    queryClient.setQueryData<PresencePayload>(key, { agent_id: p.agent_id, status: p.status });
  }) as WSEnvelopeHandler);
}
