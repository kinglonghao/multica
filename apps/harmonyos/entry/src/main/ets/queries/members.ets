/**
 * Workspace member list. Mirrors `apps/mobile/data/queries/members.ts`.
 *
 * Used by the assignee picker on issue detail + new-issue screens. The
 * cache is invalidated by `member:added` / `member:updated` /
 * `member:removed` WS events so the picker stays current when a
 * workspace admin invites / promotes a teammate.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { MemberWithUser } from '../models/types';

export const memberListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['members', wsId];
  };

export function useMemberListQuery(onUpdate?: () => void): QueryHandle<MemberWithUser[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 60_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<MemberWithUser[]>(
    memberListKey(wsId),
    ({ signal }) => api.listMembers({ signal }),
    opts
  );
}
