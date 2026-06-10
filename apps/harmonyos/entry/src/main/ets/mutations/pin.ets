import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { PinnedItem, ReorderPinsRequest } from '../models/types';

/**
 * Pin mutations. Mirrors the iOS client's
 * `apps/mobile/data/mutations/pin.ts`.
 *
 * The server pins endpoint is intentionally a flat list per user;
 * we cache the full list under ['pins', wsId] and the mutations
 * patch it in place. The actual API call validates server-side
 * uniqueness; on conflict (e.g. duplicate pin) we invalidate
 * and refetch.
 */

const pinsKey = (): readonly (string | number | boolean)[] => ['pins', workspaceStore.currentId];

export async function addPin(itemId: string, itemType: 'issue' | 'project' | 'doc'): Promise<PinnedItem> {
  const prior = queryClient.get<PinnedItem[]>(pinsKey())?.data ?? [];
  // Optimistic placeholder pinned at the end of the list.
  const temp: PinnedItem = {
    id: `temp-${itemId}`,
    type: itemType,
    workspace_id: workspaceStore.currentId ?? '',
    position: prior.length,
    item_id: itemId,
    item: null,
    created_at: new Date().toISOString()
  };
  queryClient.setQueryData<PinnedItem[]>(pinsKey(), [...prior, temp]);
  try {
    const saved = await api.addPin(itemId, itemType);
    // Replace the temp entry with the server's record.
    queryClient.setQueryData<PinnedItem[]>(pinsKey(), (prev: PinnedItem[] | undefined) => {
      const list = prev ? prev.filter(p => p.id !== temp.id) : [];
      list.push(saved);
      return list;
    });
    return saved;
  } catch (err) {
    // Rollback
    queryClient.setQueryData<PinnedItem[]>(pinsKey(), prior);
    throw err;
  }
}

export async function removePin(pinId: string): Promise<void> {
  const prior = queryClient.get<PinnedItem[]>(pinsKey())?.data ?? [];
  queryClient.setQueryData<PinnedItem[]>(pinsKey(), prior.filter(p => p.id !== pinId));
  try {
    await api.removePin(pinId);
  } catch (err) {
    queryClient.setQueryData<PinnedItem[]>(pinsKey(), prior);
    throw err;
  }
}

export async function reorderPins(req: ReorderPinsRequest): Promise<PinnedItem[]> {
  const prior = queryClient.get<PinnedItem[]>(pinsKey())?.data ?? [];
  // Optimistic: re-sort locally per the new order, then sync.
  const byId = new Map(prior.map(p => [p.id, p]));
  const reordered = req.pinned_ids
    .map((id, idx) => {
      const pin = byId.get(id);
      return pin ? { ...pin, position: idx } : null;
    })
    .filter((p): p is PinnedItem => p !== null);
  queryClient.setQueryData<PinnedItem[]>(pinsKey(), reordered);
  try {
    const saved = await api.reorderPins(req);
    queryClient.setQueryData<PinnedItem[]>(pinsKey(), saved);
    return saved;
  } catch (err) {
    queryClient.setQueryData<PinnedItem[]>(pinsKey(), prior);
    throw err;
  }
}
