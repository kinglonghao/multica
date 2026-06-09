import { QueryHandle, useQuery, QueryOptions } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { InboxItem } from '../models/types';

export function inboxQueryKey(wsId: string | null) {
  return ['inbox', wsId] as const;
}

/**
 * Subscribe to the inbox list. Pass an `onUpdate` callback so the
 * page can bump a `@Local version` counter and re-render when the
 * cache mutates (initial fetch, refetch, optimistic patch from
 * a mutation, or a WS-driven cache update).
 */
export function useInboxQuery(onUpdate?: () => void): QueryHandle<InboxItem[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<InboxItem[]>(
    inboxQueryKey(wsId),
    ({ signal }) => api.listInbox({ signal }),
    opts
  );
}
