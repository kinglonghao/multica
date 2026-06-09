import { QueryHandle, useQuery, QueryOptions } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Project, ListProjectsResponse } from '../models/types';

export function projectListKey(wsId: string | null) {
  return ['projects', wsId] as const;
}

export function useProjectListQuery(onUpdate?: () => void): QueryHandle<ListProjectsResponse> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<ListProjectsResponse>(
    projectListKey(wsId),
    ({ signal }) => api.listProjects({ signal }),
    opts
  );
}

export function projectDetailKey(wsId: string | null, id: string) {
  return ['project', wsId, id] as const;
}

export function useProjectDetailQuery(
  id: string,
  onUpdate?: () => void
): QueryHandle<Project> {
  const wsId = workspaceStore.currentId;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<Project>(
    projectDetailKey(wsId, id),
    ({ signal }) => api.getProject(id, { signal }),
    opts
  );
}
