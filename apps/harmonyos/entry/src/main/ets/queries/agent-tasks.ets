/**
 * Agent task / run list. Mirrors `apps/mobile/data/queries/agents.ts` and
 * `apps/mobile/data/queries/agent-task-snapshot.ts`.
 *
 * Two cache shapes:
 *   - per-agent runs (`agent-tasks`, wsId, agentId) — consumed by the
 *     agent-detail Runs tab (H2).
 *   - issue-scoped runs (`issue-runs`, issueId) — the "agent runs for
 *     this issue" surface, also fed by `task:running` / `task:completed`
 *     WS events so the issue detail can render the live execution
 *     timeline.
 *
 * The `AgentTask` row carries the same fields as the web's
 * `agent_tasks` table (status, failure_reason, prompt, started_at,
 * finished_at, duration_ms, cost_usd). The list is "small + cold" —
 * agents don't usually run more than a handful of tasks per session —
 * so we keep the stale time at 30s and let WS patches overwrite in
 * place.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { AgentTask } from '../models/types';

export const agentTasksKey: (wsId: string | null, agentId: string) => QueryKey =
  (wsId: string | null, agentId: string): QueryKey => {
    return ['agent-tasks', wsId, agentId];
  };

export function useAgentTasksQuery(
  agentId: string,
  onUpdate?: () => void
): QueryHandle<AgentTask[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<AgentTask[]>(
    agentTasksKey(wsId, agentId),
    ({ signal }) => api.listAgentTasks(agentId, { signal }),
    opts
  );
}

export const issueRunsKey: (wsId: string | null, issueId: string) => QueryKey =
  (wsId: string | null, issueId: string): QueryKey => {
    return ['issue-runs', wsId, issueId];
  };

/**
 * "Runs" for an issue — the agent tasks spawned by actions on the
 * issue (assign-to-agent, dispatch, etc.). The list shape comes from
 * the same `AgentTask` row, filtered to the issue_id the server
 * stamps onto the row when the issue dispatches the agent.
 *
 * WS handler: `useTaskRealtime` patches this list on every
 * `task:running` / `task:completed` / `task:failed` event with the
 * matching `issue_id`.
 */
export function useIssueRunsQuery(
  issueId: string,
  onUpdate?: () => void
): QueryHandle<AgentTask[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<AgentTask[]>(
    issueRunsKey(wsId, issueId),
    async ({ signal }) => {
      // Server endpoint: /api/issues/:id/runs (added in M3). When
      // the endpoint is missing the parser falls back to [] so the
      // page renders an empty state rather than throwing.
      try {
        return await api.listIssueRuns(issueId, { signal });
      } catch {
        return [] as AgentTask[];
      }
    },
    opts
  );
}
