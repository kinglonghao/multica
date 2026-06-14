import { QueryHandle, useQuery, QueryOptions, QueryKey, FetchContext } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Project, ListProjectsResponse } from '../models/types';

export const projectListKey: (wsId: string | null) => QueryKey =
  (wsId: string | null): QueryKey => {
    return ['projects', wsId];
  };

export function useProjectListQuery(onUpdate?: () => void): QueryHandle<ListProjectsResponse> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<ListProjectsResponse>(
    projectListKey(wsId),
    (ctx: FetchContext) => api.listProjects({ cancelToken: ctx.cancelToken }),
    opts
  );
}

export const projectDetailKey: (wsId: string | null, id: string) => QueryKey =
  (wsId: string | null, id: string): QueryKey => {
    return ['project', wsId, id];
  };

export function useProjectDetailQuery(
  id: string,
  onUpdate?: () => void
): QueryHandle<Project> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Project>(
    projectDetailKey(wsId, id),
    (ctx: FetchContext) => api.getProject(id, { cancelToken: ctx.cancelToken }),
    opts
  );
}
