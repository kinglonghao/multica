/**
 * Runtime / device list. Mirrors `apps/mobile/data/queries/runtimes.ts`.
 *
 * Feeds the `online` dot in the agent header / picker and the
 * `WorkspaceAgentAvailability` calculator. The runtime list is
 * invalidated by `daemon:register` / `daemon:heartbeat` and on
 * reconnect — see `realtime-hooks.ets::useRuntimeRealtime`.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { RuntimeDevice } from '../models/types';

export const runtimeListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['runtimes', wsId];
  };

export function useRuntimeListQuery(onUpdate?: () => void): QueryHandle<RuntimeDevice[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<RuntimeDevice[]>(
    runtimeListKey(wsId),
    ({ signal }) => api.listRuntimes({ signal }),
    opts
  );
}
