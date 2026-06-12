/**
 * Workspace squad list. Mirrors `apps/mobile/data/queries/squads.ts`.
 *
 * Used by the agent / squad picker and the More → Squads screen.
 * `squad:*` WS events invalidate the cache (server contract does not
 * carry a stable payload shape for squad diffs, so invalidate is
 * cheaper than risking a malformed patch).
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Squad } from '../models/types';

export const squadListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['squads', wsId];
  };

export function useSquadListQuery(onUpdate?: () => void): QueryHandle<Squad[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 60_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Squad[]>(
    squadListKey(wsId),
    ({ signal }) => api.listSquads({ signal }),
    opts
  );
}
