/**
 * Workspace agent list. Mirrors `apps/mobile/data/queries/agents.ts`.
 *
 * Feeds the assignee picker (member OR agent), the agents tab,
 * and the agent-detail "Runs" sub-page. `agent:*` WS events
 * invalidate the list — see
 * `realtime-hooks.ets::useAgentRealtime`.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Agent } from '../models/types';

export const agentListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['agents', wsId];
  };

export function useAgentListQuery(onUpdate?: () => void): QueryHandle<Agent[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 60_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Agent[]>(
    agentListKey(wsId),
    ({ signal }) => api.listAgents({ signal }),
    opts
  );
}
