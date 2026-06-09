import { useQuery, QueryHandle } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { InboxItem } from '../models/types';

export function inboxQueryKey(wsId: string | null) {
  return ['inbox', wsId] as const;
}

export function useInboxQuery(): QueryHandle<InboxItem[]> {
  const wsId = workspaceStore.currentId;
  return useQuery<InboxItem[]>(
    inboxQueryKey(wsId),
    ({ signal }) => api.listInbox({ signal }),
    { staleTimeMs: 30_000 }
  );
}
