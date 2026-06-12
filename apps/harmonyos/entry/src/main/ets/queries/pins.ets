/**
 * Workspace pin list. Mirrors `apps/mobile/data/queries/pins.ts`.
 *
 * Keyed on (wsId, userId) because pin lists are per-user-per-workspace
 * — each member curates their own sidebar pins, so keying only on
 * wsId would mix two users on a shared device. The HarmonyOS
 * current-user id is read from `Preferences`, matching how
 * `auth.ets` reads the same field at boot.
 */
import { Preferences } from '../data/preferences';
import { QueryHandle, useQuery, QueryOptions, QueryKey } from './cache';
import { api } from '../data/api';
import { workspaceStore } from '../data/workspace';
import { PinnedItem } from '../models/types';

export const pinListKey: (wsId: string | null, userId: string | null) => QueryKey =
  (wsId: string | null, userId: string | null): QueryKey => {
    return ['pins', wsId, userId];
  };

export function usePinListQuery(onUpdate?: () => void): QueryHandle<PinnedItem[]> {
  const wsId = workspaceStore.currentId;
  const userId = Preferences.get('userId') ?? null;
  const opts: QueryOptions = { staleTimeMs: 30_000 };
  if (onUpdate) opts.onUpdate = onUpdate;
  return useQuery<PinnedItem[]>(
    pinListKey(wsId, userId),
    ({ signal }) => api.listPins({ signal }),
    opts
  );
}
