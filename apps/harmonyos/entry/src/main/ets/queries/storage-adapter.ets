/**
 * Persistent cache storage adapter.
 *
 * The in-memory `QueryClient` (queries/cache.ets) is fast but
 * ephemeral — every cold start re-fetches every list. iOS solves
 * this with TanStack Query's `persister` plug-in; the HarmonyOS
 * build needs the same on top of `@ohos.data.preferences`.
 *
 * Design:
 *   - One preferences store per workspace, named
 *     `multica_query_cache_<wsId>`. Keying per workspace keeps
 *     sensitive data scoped (signing out of one workspace and
 *     into another is a hard reset on the cache for the previous
 *     one).
 *   - Each cache entry is a single key/value pair:
 *     `key: state` where `state` is the JSON-serialised
 *     `QueryState<T>`. We only persist the data / updatedAt
 *     fields — `isLoading` / `isRefetching` are recomputed on
 *     boot from the existence of `data`.
 *   - The adapter is intentionally conservative: it does NOT
 *     persist the AbortController / inflight promise / observers.
 *     Those are runtime-only and rehydrating them would be a
 *     recipe for ghost-in-flight requests.
 *   - `saveAll` is debounced via a coalescing timer so a burst
 *     of mutations doesn't hammer disk. The timer fires within
 *     250 ms of the last `saveAll` call, which is well under the
 *     perceived-snappiness threshold for a write-then-kill-app
 *     scenario.
 *   - `loadAll` is best-effort: any per-entry parse failure is
 *     logged and the entry is dropped. A corrupted cache must
 *     not brick the boot path.
 *
 * The cache calls into the adapter through two hooks:
 *   - `installStorageAdapter(adapter)` from `EntryAbility` boot,
 *     after `PreferencesBootstrap.init()`.
 *   - `queryClient.persistSnapshot()` on every successful fetch
 *     (the cache module fires this through its own private
 *     observer). The adapter schedules the debounced flush.
 *   - `queryClient.hydrateFromStorage()` on first subscribe —
 *     seeds the in-memory entry from disk before the network
 *     round-trip is fired.
 */
import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { QueryState } from './cache';

/** Persisted shape. We drop isLoading / isRefetching / error since
 *  the next fetch will recompute them; on the off chance the
 *  network never comes back, the page renders the cached data +
 *  the empty-error state. */
export interface PersistedState<T> {
  data: T | undefined;
  updatedAt: number | null;
}

export interface CacheStorageAdapter {
  /** Read a single entry. Returns undefined when the key is missing
   *  or the on-disk JSON failed to parse. */
  load<T>(key: string): Promise<PersistedState<T> | undefined>;
  /** Drop every entry in the active workspace's store. */
  clear(): Promise<void>;
  /** Schedule a debounced flush of the current in-memory snapshot.
   *  The adapter owns the debounce — callers fire-and-forget. */
  saveAll(snapshot: ReadonlyMap<string, PersistedState<unknown>>): void;
  /** Tear down the disk handle (sign-out / workspace switch). */
  close(): Promise<void>;
}

const DEBOUNCE_MS = 250;
const STORE_PREFIX = 'multica_query_cache_';
const NOOP: CacheStorageAdapter = {
  async load<T>(_key: string): Promise<PersistedState<T> | undefined> {
    return undefined;
  },
  async clear(): Promise<void> { /* noop */ },
  saveAll(_snapshot: ReadonlyMap<string, PersistedState<unknown>>): void { /* noop */ },
  async close(): Promise<void> { /* noop */ }
};

class PreferencesCacheStorageAdapter implements CacheStorageAdapter {
  private store: preferences.Preferences | null = null;
  private storeName: string;
  private debounceHandle: number | null = null;
  private pendingSnapshot: Map<string, PersistedState<unknown>> | null = null;

  constructor(wsId: string) {
    this.storeName = `${STORE_PREFIX}${wsId}`;
  }

  /**
   * Open the disk store. Idempotent — calling twice returns the
   * cached handle. The `init` must run after
   * `PreferencesBootstrap.init()` (which gives us a Context), and
   * after `workspaceStore.currentId` is populated.
   */
  async init(context: common.Context): Promise<void> {
    if (this.store) return;
    this.store = await preferences.getPreferences(context, this.storeName);
  }

  async load<T>(key: string): Promise<PersistedState<T> | undefined> {
    if (!this.store) return undefined;
    try {
      const raw = await this.store.get(key, '') as string;
      if (!raw) return undefined;
      const parsed = JSON.parse(raw) as PersistedState<T>;
      // Defensive: a corrupted entry that doesn't have an
      // updatedAt would silently never expire, so we always
      // normalise the shape here.
      return {
        data: parsed.data,
        updatedAt: typeof parsed.updatedAt === 'number' ? parsed.updatedAt : null
      };
    } catch (err) {
      console.warn('[storage] load failed for', key, err);
      return undefined;
    }
  }

  async clear(): Promise<void> {
    if (!this.store) return;
    await this.store.clear();
  }

  saveAll(snapshot: ReadonlyMap<string, PersistedState<unknown>>): void {
    this.pendingSnapshot = new Map(snapshot);
    if (this.debounceHandle !== null) return;
    this.debounceHandle = setTimeout(() => {
      this.debounceHandle = null;
      const snap = this.pendingSnapshot;
      this.pendingSnapshot = null;
      if (snap) this.flushSync(snap);
    }, DEBOUNCE_MS) as unknown as number;
  }

  private async flushSync(snapshot: Map<string, PersistedState<unknown>>): Promise<void> {
    if (!this.store) return;
    // Delete-then-put — the store API doesn't expose a bulk
    // operation and a single malformed entry shouldn't fail the
    // whole flush.
    try {
      const existingKeys = await this.store.getAll() as Record<string, string>;
      for (const k of Object.keys(existingKeys)) {
        if (!snapshot.has(k)) {
          await this.store.delete(k);
        }
      }
      for (const [k, v] of snapshot.entries()) {
        await this.store.put(k, JSON.stringify(v));
      }
      await this.store.flush();
    } catch (err) {
      console.warn('[storage] flush failed', err);
    }
  }

  async close(): Promise<void> {
    if (this.debounceHandle !== null) {
      clearTimeout(this.debounceHandle);
      this.debounceHandle = null;
    }
    if (this.pendingSnapshot) {
      await this.flushSync(this.pendingSnapshot);
      this.pendingSnapshot = null;
    }
    // preferences.Preferences does not expose a `close` API; the
    // handle is GC'd and the next call to `getPreferences` will
    // return the same store, so we drop our reference.
    this.store = null;
  }
}

let activeAdapter: CacheStorageAdapter = NOOP;

export function getStorageAdapter(): CacheStorageAdapter {
  return activeAdapter;
}

/**
 * Replace the active adapter. Pass `null` to reset to the noop
 * (used on sign-out / workspace switch where the previous
 * workspace's store must not be read from). The new adapter
 * takes effect immediately — in-flight cache lookups on the
 * NEXT subscribe will see the new handle.
 */
export async function setStorageAdapter(adapter: CacheStorageAdapter | null): Promise<void> {
  if (activeAdapter !== NOOP) {
    await activeAdapter.close();
  }
  activeAdapter = adapter ?? NOOP;
}

/**
 * Build a per-workspace storage adapter. Caller owns the
 * `Preferences` context and the workspace id. The function
 * initialises the disk store eagerly so the first hydrate
 * doesn't pay a blocking await on the hot path.
 */
export async function createWorkspaceCacheStorageAdapter(
  context: common.Context,
  wsId: string
): Promise<CacheStorageAdapter> {
  const adapter = new PreferencesCacheStorageAdapter(wsId);
  await adapter.init(context);
  return adapter;
}
