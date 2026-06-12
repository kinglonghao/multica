/**
 * Minimal reactive query cache. Mirrors (a subset of) TanStack Query.
 *
 * The HarmonyOS build doesn't have @tanstack/react-query as a usable
 * dependency — it ships for React/React Native, not ArkUI — and
 * porting the full TQ surface is a multi-week project we don't need
 * for v0.1. Instead we run a small cache with the same shape TQ uses
 * (keyed lookups, refetch-on-demand, setQueryData) plus a per-key
 * AbortController so the same "cancellation" contract from
 * apps/mobile/CLAUDE.md §4 holds here.
 *
 * REACTIVITY (V2):
 * ArkUI doesn't auto-track reads inside a plain object — when the
 * cache state mutates, the page won't re-render unless we explicitly
 * trigger it. We do that by giving the page an `onUpdate` callback
 * to bump a `@Local version: number` on the page side. The page
 * passes the callback into `useQuery`; the cache fires it on every
 * state change. The pattern is:
 *
 *   @Local version: number = 0;
 *   private query: QueryHandle<Issue> | null = null;
 *
 *   aboutToAppear() {
 *     this.query = useIssueDetailQuery(this.issueId, () => { this.version++; });
 *   }
 *
 *   build() {
 *     // Re-reads on every re-render triggered by version++.
 *     const s = this.query!.getState();
 *     if (s.isLoading) { ... }
 *   }
 *
 * The `getState()` getter is what makes the read fresh after a
 * re-render. The earlier v0.1 used a captured-at-subscribe `state`
 * object that the page stored and never refreshed — that was the
 * bug behind the "page only reads state once" code-review finding.
 *
 * Note (C-1): ArkTS forbids `unknown` and bare `any` (the latter
 * since strict mode 1.1). The cache stores entries as a typed
 * record of `QueryState<T>` per key — the per-entry generic flows
 * from the `Fetcher<T>` parameter at subscribe time, so the
 * `Map<string, EntryRecord<T>>` shape stays concrete.
 */

import { ApiError } from '../data/api';
import { getStorageAdapter, PersistedState } from './storage-adapter';

export interface QueryState<T> {
  data: T | undefined;
  error: Error | null;
  isLoading: boolean;
  isRefetching: boolean;
  updatedAt: number | null;
}

/**
 * Query key. ArkTS-safe — only string / number / boolean entries
 * (a tagged tuple shape that JSON.stringifies stably). The cache
 * `keyOf` helper joins these with `|` so we never have to JSON-
 * stringify at runtime (JSON.parse / JSON.stringify on dynamic
 * shapes is also a strict-mode footgun).
 */
export type QueryKey = ReadonlyArray<string | number | boolean>;

export type Fetcher<T> = (ctx: { signal: AbortSignal }) => Promise<T>;

interface InternalEntry<T> {
  state: QueryState<T>;
  controller: AbortController | null;
  inflight: Promise<T> | null;
  staleTimeMs: number;
  observers: Set<() => void>;
}

export interface QueryOptions {
  staleTimeMs?: number;
  enabled?: boolean;
  /** Fired on every state change. Used by the page to bump a
   *  `@Local version` counter and trigger a re-render. */
  onUpdate?: () => void;
}

export interface QueryHandle<T> {
  /** Read the current state. Safe to call inside `build()`. */
  getState: () => QueryState<T>;
  /** Force a fresh fetch. */
  refetch: () => void;
  /** Abort the in-flight request, if any. Does NOT drop the cached
   *  value — the next `refetch()` will fill in fresh data. */
  cancel: () => void;
  /** Detach this subscriber from the cache. Idempotent. */
  unsubscribe: () => void;
}

/**
 * Internal entry record. We keep the `key` next to the state so
 * `setQueryData` and friends can find an entry without forcing the
 * caller to thread the original key through.
 */
interface EntryRecord {
  // The state is stored untyped at the dict level because ArkTS
  // can't express `Map<string, { state: QueryState<T> }>` with
  // T varying per key. Each `getState` call casts to the page's
  // expected T — the call site owns the type contract.
  state: QueryState<unknown>;
  controller: AbortController | null;
  inflight: Promise<unknown> | null;
  staleTimeMs: number;
  observers: Set<() => void>;
}

class QueryClient {
  private readonly entries: Map<string, EntryRecord> = new Map();

  private keyOf(key: QueryKey): string {
    return key.join('|');
  }

  /**
   * Synchronous read of a cached entry. Returns undefined when
   * the key has no cache entry (the typical case before the
   * first fetch settles). Mutations use this to read the
   * optimistic-patch baseline before applying their own write.
   */
  get<T>(key: QueryKey): QueryState<T> | undefined {
    const entry = this.entries.get(this.keyOf(key));
    return entry ? (entry.state as QueryState<T>) : undefined;
  }

  subscribe<T>(
    key: QueryKey,
    fetcher: Fetcher<T>,
    options: QueryOptions = {}
  ): QueryHandle<T> {
    const stringKey = this.keyOf(key);
    let entry: EntryRecord | undefined = this.entries.get(stringKey);
    if (!entry) {
      entry = {
        state: { data: undefined, error: null, isLoading: true, isRefetching: false, updatedAt: null },
        controller: null,
        inflight: null,
        staleTimeMs: options.staleTimeMs ?? 0,
        observers: new Set()
      };
      this.entries.set(stringKey, entry);
    } else if (options.staleTimeMs !== undefined) {
      entry.staleTimeMs = options.staleTimeMs;
    }

    // Eagerly seed from disk so a cold-launched app can render
    // the cached list before the first network round-trip
    // completes. The hydrate is fire-and-forget — when it
    // resolves we patch the entry (if it hasn't been replaced by
    // an in-flight fetch) and notify observers so the page
    // re-renders with the warm cache.
    this.hydrateFromStorage(stringKey, entry);

    // Each call to subscribe adds its own observer so the page that
    // owns this subscription gets a notification on every state change.
    const observer = (): void => {
      if (options.onUpdate) options.onUpdate();
    };
    entry.observers.add(observer);

    const startFetch = (force: boolean): void => {
      const cur = this.entries.get(stringKey);
      if (!cur) return;
      const stale = cur.state.updatedAt === null ||
        Date.now() - cur.state.updatedAt > cur.staleTimeMs;
      if (cur.inflight && !force) return;
      if (!stale && !force && cur.state.data !== undefined) {
        cur.state = { ...cur.state, isLoading: false };
        return;
      }
      const controller = new AbortController();
      cur.controller?.abort();
      cur.controller = controller;
      cur.state = {
        ...cur.state,
        isLoading: cur.state.data === undefined,
        isRefetching: cur.state.data !== undefined,
        error: null
      };
      this.notify(stringKey);
      const promise = fetcher({ signal: controller.signal })
        .then((data: T) => {
          const e = this.entries.get(stringKey);
          if (!e) return data;
          e.state = {
            data,
            error: null,
            isLoading: false,
            isRefetching: false,
            updatedAt: Date.now()
          };
          e.inflight = null;
          this.notify(stringKey);
          this.persistSnapshot();
          return data;
        })
        .catch((err: Error) => {
          const e = this.entries.get(stringKey);
          if (!e) throw err;
          if (err instanceof ApiError && err.status === 0) {
            e.state = { ...e.state, isLoading: false, isRefetching: false };
            this.notify(stringKey);
            return undefined as unknown as T;
          }
          e.state = {
            ...e.state,
            error: err,
            isLoading: false,
            isRefetching: false
          };
          e.inflight = null;
          this.notify(stringKey);
          throw err;
        });
      cur.inflight = promise;
    };

    if (entry.state.data === undefined && !entry.inflight) {
      startFetch(false);
    } else {
      const stale = entry.state.updatedAt === null ||
        Date.now() - entry.state.updatedAt > entry.staleTimeMs;
      if (stale && !entry.inflight) {
        startFetch(true);
      }
    }

    let unsubscribed = false;
    return {
      getState: (): QueryState<T> => {
        const e = this.entries.get(stringKey);
        if (!e) {
          return { data: undefined, error: null, isLoading: true, isRefetching: false, updatedAt: null };
        }
        return e.state as QueryState<T>;
      },
      refetch: (): void => { startFetch(true); },
      cancel: (): void => {
        const e = this.entries.get(stringKey);
        e?.controller?.abort();
      },
      unsubscribe: (): void => {
        if (unsubscribed) return;
        unsubscribed = true;
        const e = this.entries.get(stringKey);
        if (!e) return;
        e.observers.delete(observer);
        if (e.observers.size === 0) {
          e.controller?.abort();
          this.entries.delete(stringKey);
        }
      }
    };
  }

  setQueryData<T>(key: QueryKey, data: T | ((prev: T | undefined) => T)): void {
    const stringKey = this.keyOf(key);
    const entry = this.entries.get(stringKey);
    const prev = entry?.state.data as T | undefined;
    const next = typeof data === 'function'
      ? (data as (p: T | undefined) => T)(prev)
      : data;
    if (entry) {
      entry.state = { ...entry.state, data: next, error: null, updatedAt: Date.now() };
      this.notify(stringKey);
    } else {
      this.entries.set(stringKey, {
        state: { data: next, error: null, isLoading: false, isRefetching: false, updatedAt: Date.now() },
        controller: null,
        inflight: null,
        staleTimeMs: 0,
        observers: new Set()
      });
    }
    this.persistSnapshot();
  }

  invalidate(key: QueryKey): void {
    this.entries.delete(this.keyOf(key));
  }

  /**
   * Drop every cache entry whose serialized key STARTS WITH the
   * given prefix. Used by mutations that want to invalidate
   * "every list-shaped query for the current workspace" without
   * knowing the exact per-list subkey — the new-issue flow
   * invalidates ['issues', wsId, ...] for every variant of
   * params the lists may have been opened with.
   */
  invalidatePrefix(prefix: QueryKey): void {
    const prefixStr = this.keyOf(prefix);
    for (const key of Array.from(this.entries.keys())) {
      if (key.startsWith(prefixStr + '|') || key === prefixStr) {
        this.entries.delete(key);
      }
    }
  }

  clear(): void {
    for (const entry of this.entries.values()) {
      entry.controller?.abort();
    }
    this.entries.clear();
    // Also wipe disk — `clear()` is the nuclear option used on
    // sign-out, and we don't want a re-login to rehydrate stale
    // workspace data.
    getStorageAdapter().clear().catch(() => { /* noop */ });
  }

  /**
   * Eagerly seed an entry from the persistent storage adapter.
   * Fires-and-forgets the disk read; on resolution the entry is
   * patched (if still present) and observers are notified.
   *
   * We never block the in-memory path on disk — a slow disk read
   * is the worst case we want to avoid, and the adapter already
   * has its own try/catch around JSON.parse. The fetch that
   * `subscribe` kicks off in parallel may complete first; if so,
   * the hydrate is a no-op (we skip patching when the in-memory
   * entry has been updated more recently than the disk record).
   */
  private hydrateFromStorage(stringKey: string, entry: EntryRecord): void {
    const adapter = getStorageAdapter();
    adapter.load<unknown>(stringKey).then((persisted) => {
      if (!persisted) return;
      const cur = this.entries.get(stringKey);
      if (!cur) return;
      // Don't overwrite a fresher in-memory value.
      const inMemFresh = cur.state.updatedAt !== null &&
        (persisted.updatedAt === null || cur.state.updatedAt >= persisted.updatedAt);
      if (inMemFresh) return;
      cur.state = {
        data: persisted.data,
        error: null,
        isLoading: false,
        isRefetching: false,
        updatedAt: persisted.updatedAt
      };
      this.notify(stringKey);
    }).catch(() => { /* noop */ });
  }

  /**
   * Persist the current in-memory cache snapshot to the storage
   * adapter. Called on every successful fetch and every
   * `setQueryData` write. The adapter owns debouncing — we
   * build a fresh snapshot each time so a stale-write race
   * can't drop the latest state.
   */
  private persistSnapshot(): void {
    const snapshot = new Map<string, PersistedState<unknown>>();
    for (const [k, e] of this.entries.entries()) {
      // Only persist settled entries (have data + updatedAt).
      // Entries still in `isLoading` or that have only ever
      // errored are skipped — the next successful fetch will
      // repopulate them.
      if (e.state.updatedAt === null) continue;
      snapshot.set(k, {
        data: e.state.data,
        updatedAt: e.state.updatedAt
      });
    }
    getStorageAdapter().saveAll(snapshot);
  }

  private notify(stringKey: string): void {
    const entry = this.entries.get(stringKey);
    if (!entry) return;
    for (const obs of entry.observers) {
      try {
        obs();
      } catch (err) {
        console.warn('[query] observer threw', err);
      }
    }
  }
}

export const queryClient: QueryClient = new QueryClient();

/**
 * `useQuery` — entry point for pages. Returns a `QueryHandle<T>` whose
 * `getState()` reads the latest cache value on every call. Combine with
 * a `@Local version: number` + `bumpVersion` callback on the page so
 * the cache can trigger re-renders.
 *
 * Pages must call this from `aboutToAppear` (NOT a field initializer)
 * — the field initializer runs before `aboutToAppear` and would capture
 * stale `this.issueId` / `this.workspaceId` values, kicking the fetch
 * with an empty key.
 */
export function useQuery<T>(
  key: QueryKey,
  fetcher: Fetcher<T>,
  options: QueryOptions = {}
): QueryHandle<T> {
  return queryClient.subscribe(key, fetcher, options);
}
