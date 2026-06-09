import { useQuery, QueryHandle } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { Project, ListProjectsResponse } from '../models/types';

export function projectListKey(wsId: string | null) {
  return ['projects', wsId] as const;
}

export function useProjectListQuery(): QueryHandle<ListProjectsResponse> {
  const wsId = workspaceStore.currentId;
  return useQuery<ListProjectsResponse>(
    projectListKey(wsId),
    ({ signal }) => api.listProjects({ signal }),
    { staleTimeMs: 30_000 }
  );
}

export function projectDetailKey(wsId: string | null, id: string) {
  return ['project', wsId, id] as const;
}

export function useProjectDetailQuery(id: string): QueryHandle<Project> {
  const wsId = workspaceStore.currentId;
  return useQuery<Project>(
    projectDetailKey(wsId, id),
    ({ signal }) => api.getProject(id, { signal }),
    { staleTimeMs: 30_000 }
  );
}
