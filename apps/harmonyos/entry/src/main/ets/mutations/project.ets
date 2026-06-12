/**
 * Project + project-resource mutations. Mirrors the iOS
 * client's `apps/mobile/data/mutations/projects.ts` — every
 * mutation here goes through the shared `runOptimistic` /
 * `mutateDetail` helpers from `./optimistic.ets` so the
 * snapshot → patch → server → rollback → invalidate lifecycle
 * stays in one place.
 *
 * M3 (WS-107) additions:
 *   - `updateProject` — optimistic patch for the project
 *     detail cache; the project list prefix is invalidated
 *     so any list view re-ranks on the next refetch.
 *   - `createProjectResource` — posts the new resource and
 *     invalidates the project's resource-list cache so the
 *     page picks up the new row on its next render.
 *   - `addPin` / `removePin` / `reorderPins` — pin mutations
 *     live here too (the iOS app puts them in
 *     `data/mutations/pins.ts`; we keep the same surface).
 */
import { api } from '../data/api';
import { queryClient, QueryKey } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { PinnedItem, Project, ProjectResource, ReorderPinsRequest, UpdateProjectRequest } from '../models/types';
import { runOptimistic, mutateDetail } from './optimistic';
import { projectDetailKey } from '../queries/project';
import { pinListKey } from '../queries/pins';
import { Preferences } from '../data/preferences';

const wsId = (): string | null => workspaceStore.currentId;

const projectResourcesKey = (projectId: string): readonly (string | number | boolean)[] =>
  ['project-resources', projectId];

const listPrefixesForWs = (): ReadonlyArray<QueryKey> => {
  const cur = wsId();
  if (!cur) return [];
  return [['projects', cur]];
};

const pinKeyForCurrentUser = (): ReadonlyArray<QueryKey> => {
  const cur = wsId();
  const userId = Preferences.get('userId') ?? null;
  return [...pinListKey(cur, userId)];
};

/**
 * Optimistic project update. Patches the detail cache, sends
 * the PATCH, and on success overwrites with the server's
 * response. The list prefix is invalidated so any list view
 * re-ranks.
 */
export async function updateProject(projectId: string, req: UpdateProjectRequest): Promise<Project> {
  return mutateDetail<Project>(
    projectDetailKey(wsId(), projectId),
    (prev: Project | undefined) => {
      if (!prev) return prev;
      const next: Project = { ...prev };
      if (req.name !== undefined) next.name = req.name;
      if (req.description !== undefined) next.description = req.description;
      if (req.status !== undefined) next.status = req.status;
      if (req.priority !== undefined) next.priority = req.priority;
      if (req.lead_id !== undefined) {
        next.lead_id = req.lead_id;
        // The lead_name / lead_avatar_url fields are denormalised
        // on the server response but the PATCH body doesn't
        // carry them; we clear them so the page re-renders
        // without a stale name. The post-settle overwrite from
        // the server will fill them in.
        next.lead_name = null;
        next.lead_avatar_url = null;
      }
      if (req.start_date !== undefined) next.start_date = req.start_date;
      if (req.target_date !== undefined) next.target_date = req.target_date;
      next.updated_at = new Date().toISOString();
      return next;
    },
    () => api.updateProject(projectId, req),
    listPrefixesForWs()
  );
}

/**
 * Add a resource to a project. Returns the server-issued
 * `ProjectResource` row; the caller is expected to push it
 * into the local list cache so the page renders it without a
 * refetch.
 */
export async function createProjectResource(
  projectId: string,
  req: { name: string; url?: string; type: string }
): Promise<ProjectResource> {
  const resource = await api.createProjectResource(projectId, req);
  queryClient.invalidate(projectResourcesKey(projectId));
  return resource;
}

/**
 * Optimistic pin add. The local cache gains a synthetic
 * `PinnedItem` immediately (the server response overwrites
 * with the real one on success), so the sidebar updates
 * without a refetch. Rollback on failure.
 */
export async function addPin(itemId: string, itemType: 'issue' | 'project' | 'doc'): Promise<PinnedItem> {
  const key = pinKeyForCurrentUser();
  const optimistic: PinnedItem = {
    id: `optimistic-${Date.now()}`,
    type: itemType,
    workspace_id: wsId() ?? '',
    position: 0,
    item_id: itemId,
    item: null,
    created_at: new Date().toISOString()
  };
  return runOptimistic<PinnedItem[], PinnedItem, PinnedItem[] | undefined>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<PinnedItem[]>(key)?.data;
      const next = prior ? [...prior] : [];
      next.unshift(optimistic);
      queryClient.setQueryData<PinnedItem[]>(key, next);
      return prior;
    },
    request: () => api.addPin(itemId, itemType),
    rollback: (prior) => {
      if (prior === undefined) {
        queryClient.invalidate(key);
      } else {
        queryClient.setQueryData<PinnedItem[]>(key, prior);
      }
    },
    onSuccess: (server: PinnedItem) => {
      const cur = queryClient.get<PinnedItem[]>(key)?.data ?? [];
      const next = cur.map((p) => (p.id === optimistic.id ? server : p));
      queryClient.setQueryData<PinnedItem[]>(key, next);
    }
  }).then((r) => {
    if (r.rolledBack) throw new Error('Pin add rolled back');
    if (!r.response) throw new Error('Pin add aborted');
    return r.response;
  });
}

export async function removePin(pinId: string): Promise<void> {
  const key = pinKeyForCurrentUser();
  await runOptimistic<PinnedItem[], void, PinnedItem[] | undefined>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<PinnedItem[]>(key)?.data;
      const next = (prior ?? []).filter((p) => p.id !== pinId);
      queryClient.setQueryData<PinnedItem[]>(key, next);
      return prior;
    },
    request: async () => {
      await api.removePin(pinId);
    },
    rollback: (prior) => {
      if (prior === undefined) {
        queryClient.invalidate(key);
      } else {
        queryClient.setQueryData<PinnedItem[]>(key, prior);
      }
    }
  });
}

export async function reorderPins(req: ReorderPinsRequest): Promise<PinnedItem[]> {
  const key = pinKeyForCurrentUser();
  return runOptimistic<PinnedItem[], PinnedItem[], PinnedItem[] | undefined>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<PinnedItem[]>(key)?.data;
      const list = prior ? [...prior] : [];
      const byId = new Map(list.map((p) => [p.id, p]));
      const reordered: PinnedItem[] = [];
      for (const id of req.pinned_ids) {
        const p = byId.get(id);
        if (p) reordered.push(p);
      }
      for (const p of list) {
        if (!req.pinned_ids.includes(p.id)) reordered.push(p);
      }
      queryClient.setQueryData<PinnedItem[]>(key, reordered);
      return prior;
    },
    request: () => api.reorderPins(req),
    rollback: (prior) => {
      if (prior === undefined) {
        queryClient.invalidate(key);
      } else {
        queryClient.setQueryData<PinnedItem[]>(key, prior);
      }
    },
    onSuccess: (server: PinnedItem[]) => {
      queryClient.setQueryData<PinnedItem[]>(key, server);
    }
  }).then((r) => {
    if (r.rolledBack) throw new Error('Pin reorder rolled back');
    if (!r.response) throw new Error('Pin reorder aborted');
    return r.response;
  });
}
