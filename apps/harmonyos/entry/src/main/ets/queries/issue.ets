import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Issue, ListIssuesParams, ListIssuesResponse } from '../models/types';

export const issueListKey: (wsId: string | null, params: ListIssuesParams) => QueryKey =
  (wsId: string | null, params: ListIssuesParams): QueryKey => {
    return ['issues', wsId, JSON.stringify(params)];
  };

export function useIssueListQuery(
  params: ListIssuesParams = {},
  onUpdate?: () => void
): QueryHandle<ListIssuesResponse> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 15_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<ListIssuesResponse>(
    issueListKey(wsId, params),
    ({ signal }) => api.listIssues(params, { signal }),
    opts
  );
}

export const issueDetailKey: (wsId: string | null, id: string) => QueryKey =
  (wsId: string | null, id: string): QueryKey => {
    return ['issue', wsId, id];
  };

export function useIssueDetailQuery(
  id: string,
  onUpdate?: () => void
): QueryHandle<Issue> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 15_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Issue>(
    issueDetailKey(wsId, id),
    ({ signal }) => api.getIssue(id, { signal }),
    opts
  );
}
