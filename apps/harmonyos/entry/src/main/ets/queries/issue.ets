import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Issue, ListIssuesParams, ListIssuesResponse } from '../models/types';

// Bug 4 fix: re-export the QueryHandle type so pages that import it
// from this module (e.g. `import { QueryHandle } from '../queries/issue'`)
// resolve cleanly. The return types of useIssueListQuery / useIssueDetailQuery
// already use QueryHandle<T>, but TS module resolution still needs an
// explicit named export to satisfy `import { QueryHandle }` outside the
// file.
export type { QueryHandle } from './cache';

export const issueListKey: (wsId: string | null, params: ListIssuesParams) => QueryKey =
  (wsId: string | null, params: ListIssuesParams): QueryKey => {
    return ['issues', wsId, stableKeyOfParams(params)];
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

/**
 * Stable key serializer for query params. JSON.stringify is
 * discouraged in the cache module (it serializes object key order
 * non-deterministically across JS engines, which can produce two
 * different keys for the same logical query). This helper
 * concatenates key=value pairs in a fixed order, skipping empty
 * values, so the same logical params always hash to the same key.
 */
const stableKeyOfParams: (params: ListIssuesParams) => string =
  (params: ListIssuesParams): string => {
    const parts: string[] = [];
    if (params.status) {
      const arr = Array.isArray(params.status) ? params.status : [params.status];
      for (const s of arr) parts.push(`status=${s}`);
    }
    if (params.priority) {
      const arr = Array.isArray(params.priority) ? params.priority : [params.priority];
      for (const p of arr) parts.push(`priority=${p}`);
    }
    if (params.assignee_id) parts.push(`assignee_id=${params.assignee_id}`);
    if (params.project_id) parts.push(`project_id=${params.project_id}`);
    if (params.search) parts.push(`search=${params.search}`);
    if (params.page !== undefined) parts.push(`page=${params.page}`);
    if (params.page_size !== undefined) parts.push(`page_size=${params.page_size}`);
    return parts.join('&');
  };
