/**
 * Chat session + message queries. Mirrors
 * `apps/mobile/data/queries/chat.ts`.
 *
 * `staleTimeMs: Number.MAX_SAFE_INTEGER` (effectively Infinity) — caches
 * are kept warm by the WS event handlers in `realtime-hooks.ets`
 * (`useChatRealtime`, `useChatSessionsRealtime`). Foreground /
 * reconnect invalidates are scoped to the per-session hook that
 * owns the cache; we don't want background refetch noise.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { ChatMessage, ChatSession } from '../models/types';

export const chatKeys = {
  all: (wsId: string | null): QueryKey => ['chat', wsId],
  sessions: (wsId: string | null): QueryKey => ['chat', wsId, 'sessions'],
  messages: (sessionId: string): QueryKey => ['chat', 'messages', sessionId],
  pendingTask: (sessionId: string): QueryKey => ['chat', 'pending-task', sessionId]
};

export function useChatSessionsQuery(onUpdate?: () => void): QueryHandle<ChatSession[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: Number.MAX_SAFE_INTEGER };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<ChatSession[]>(
    chatKeys.sessions(wsId),
    ({ signal }) => api.listChatSessions({ signal }),
    opts
  );
}

export function useChatMessagesQuery(
  sessionId: string | null,
  onUpdate?: () => void
): QueryHandle<ChatMessage[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: Number.MAX_SAFE_INTEGER };
  if (onUpdate) opts.onUpdate = onUpdate;
  // Use the full chat key (which includes wsId) so the cache entry
  // gets cleared on workspace switch, but only if a sessionId is
  // present (otherwise the query is a no-op).
  const key: QueryKey = sessionId ? ['chat', wsId, 'messages', sessionId] : ['chat', wsId, 'messages', '__none__'];
  return useQuery<ChatMessage[]>(
    key,
    ({ signal }) => api.listChatMessages(sessionId as string, { signal }),
    opts
  );
}
