/**
 * Workspace label list. Mirrors `apps/mobile/data/queries/labels.ts` —
 * workspace-scoped key, consumed by the issue-detail label picker and
 * the new-issue label picker. WS-driven cache updates live in
 * `realtime-hooks.ets::useLabelRealtime`.
 */
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Label, ListLabelsResponse } from '../models/types';

export const labelListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['labels', wsId];
  };

export function useLabelListQuery(onUpdate?: () => void): QueryHandle<Label[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 60_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Label[]>(
    labelListKey(wsId),
    async ({ signal }) => {
      const res: ListLabelsResponse = await api.listLabels({ signal });
      return res.labels ?? [];
    },
    opts
  );
}

export const issueLabelsKey: (wsId: string | null, issueId: string) => QueryKey =
  (wsId: string | null, issueId: string): QueryKey => {
    return ['issue-labels', wsId, issueId];
  };

/**
 * Per-issue label set. Picked up by the issue-detail label picker and
 * refreshed on `issue_labels:changed`. Returns the full label objects
 * (id + name + color), not just ids, so the picker can render swatches
 * without a second hop into `useLabelListQuery`.
 */
export function useIssueLabelsQuery(
  issueId: string,
  onUpdate?: () => void
): QueryHandle<Label[]> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Label[]>(
    issueLabelsKey(wsId, issueId),
    async ({ signal }) => {
      const res = await api.getIssueLabels(issueId, { signal });
      return res.labels ?? [];
    },
    opts
  );
}
