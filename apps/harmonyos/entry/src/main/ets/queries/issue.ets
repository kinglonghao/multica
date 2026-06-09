import { QueryHandle, useQuery, QueryOptions } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Issue, ListIssuesParams, ListIssuesResponse } from '../models/types';

export function issueListKey(wsId: string | null, params: ListIssuesParams = {}) {
  return ['issues', wsId, JSON.stringify(params)] as const;
}

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

export function issueDetailKey(wsId: string | null, id: string) {
  return ['issue', wsId, id] as const;
}

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
