import { useQuery, QueryHandle } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Issue, ListIssuesParams, ListIssuesResponse } from '../models/types';

export function issueListKey(wsId: string | null, params: ListIssuesParams = {}) {
  return ['issues', wsId, JSON.stringify(params)] as const;
}

export function useIssueListQuery(params: ListIssuesParams = {}): QueryHandle<ListIssuesResponse> {
  const wsId = workspaceStore.currentId;
  return useQuery<ListIssuesResponse>(
    issueListKey(wsId, params),
    ({ signal }) => api.listIssues(params, { signal }),
    { staleTimeMs: 15_000 }
  );
}

export function issueDetailKey(wsId: string | null, id: string) {
  return ['issue', wsId, id] as const;
}

export function useIssueDetailQuery(id: string): QueryHandle<Issue> {
  const wsId = workspaceStore.currentId;
  return useQuery<Issue>(
    issueDetailKey(wsId, id),
    ({ signal }) => api.getIssue(id, { signal }),
    { staleTimeMs: 15_000 }
  );
}
