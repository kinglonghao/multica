/**
 * Minimal reactive query cache. Mirrors (a subset of) TanStack Query.
 *
 * The HarmonyOS build doesn't have @tanstack/react-query as a usable
 * dependency — it ships for React/React Native, not ArkUI — and
 * porting the full TQ surface is a multi-week project we don't need
 * for v0.1. Instead we run a small cache with the same shape TQ uses
 * (keyed lookups, refetch-on-demand, setQueryData) plus a per-key
 * CancelToken so the same "cancellation" contract from
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

export interface QueryState<T> {
  data: T | undefined;
  error: Error | null;
  isLoading: boolean;
  isRefetching: boolean;
  updatedAt: number | null;
}

/**
 * Query key. ArkTS-safe — string / number / boolean / null entries
 * (a tagged tuple shape that joins stably into a string key). The
 * `null` arm is required because several key prefixes thread
 * `workspaceStore.currentId: string | null` directly into the array
 * before the workspace is loaded; filtering it out would silently
 * change the key shape and fragment the cache. The cache `keyOf`
 * helper joins these with `|` (a null entry renders as the empty
 * string), so we never JSON-stringify at runtime.
 */
export type QueryKey = ReadonlyArray<string | number | boolean | null>;

/**
 * Cancellation token. Replaces the Web `AbortController`/`AbortSignal`
 * API, which the HarmonyOS runtime does not expose as globals. The
 * contract is intentionally tiny — `aborted` for the polled check and
 * `onAbort(cb)` for the callback registration. The cache creates one
 * per in-flight fetch and calls `abort()` on cancel / unsubscribe /
 * supersede; the API client (data/api.ets) reads `.aborted` and
 * destroys its httpRequest when it flips.
 */
export class CancelToken {
  aborted: boolean = false;
  private readonly listeners: Array<() => void> = [];

  abort(): void {
    if (this.aborted) return;
    this.aborted = true;
    const cbs = this.listeners;
    for (let i = 0; i < cbs.length; i++) {
      cbs[i]();
    }
  }

  onAbort(cb: () => void): void {
    if (this.aborted) {
      cb();
      return;
    }
    this.listeners.push(cb);
  }
}

/**
 * Argument passed to a Fetcher. A named interface (not an inline
 * object-literal type) so ArkTS strict mode accepts it. Carries the
 * per-request CancelToken so the fetcher can wire it into the
 * underlying HTTP client's destroy path.
 */
export interface FetchContext {
  cancelToken: CancelToken;
}

export type Fetcher<T> = (ctx: FetchContext) => Promise<T>;

interface InternalEntry<T> {
  state: QueryState<T>;
  cancelToken: CancelToken | null;
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
  state: QueryState<Object>;
  cancelToken: CancelToken | null;
  inflight: Promise<Object> | null;
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
    // Cast through Object: `QueryState<T>` for an unknown T can't
    // be checked against the concrete `QueryState<Object>` we
    // store, but the call site owns the T contract — the cast is
    // safe at runtime because we never actually inspect T here.
    return entry ? (entry.state as Object as QueryState<T>) : undefined;
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
        cancelToken: null,
        inflight: null,
        staleTimeMs: options.staleTimeMs ?? 0,
        observers: new Set()
      };
      this.entries.set(stringKey, entry);
    } else if (options.staleTimeMs !== undefined) {
      entry.staleTimeMs = options.staleTimeMs;
    }

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
        const prev = cur.state;
        cur.state = {
          data: prev.data,
          error: prev.error,
          isLoading: false,
          isRefetching: prev.isRefetching,
          updatedAt: prev.updatedAt
        };
        return;
      }
      const cancelToken = new CancelToken();
      cur.cancelToken?.abort();
      cur.cancelToken = cancelToken;
      const loadingPrev = cur.state;
      cur.state = {
        data: loadingPrev.data,
        error: null,
        isLoading: loadingPrev.data === undefined,
        isRefetching: loadingPrev.data !== undefined,
        updatedAt: loadingPrev.updatedAt
      };
      this.notify(stringKey);
      const promise = fetcher({ cancelToken: cancelToken })
        .then((data: T) => {
          const e = this.entries.get(stringKey);
          if (!e) return data;
          // Cast `data` through Object so the assignment to
          // `QueryState<Object>::data` survives ArkTS strict
          // mode (T may not be assignable to Object by name).
          const dataAsObject = data as Object;
          e.state = {
            data: dataAsObject,
            error: null,
            isLoading: false,
            isRefetching: false,
            updatedAt: Date.now()
          };
          e.inflight = null;
          this.notify(stringKey);
          return data;
        })
        .catch((err: Error) => {
          const e = this.entries.get(stringKey);
          if (!e) throw err;
          if (err instanceof ApiError && err.status === 0) {
            const abortedPrev = e.state;
            e.state = {
              data: abortedPrev.data,
              error: abortedPrev.error,
              isLoading: false,
              isRefetching: false,
              updatedAt: abortedPrev.updatedAt
            };
            this.notify(stringKey);
            // Caller doesn't read the resolved value (we keep
            // the cache entry instead of patching it), so the
            // unsafe `null as T` cast is contained to this
            // arrow. The alternative `undefined as T` doesn't
            // survive ArkTS strict mode.
            return null as T;
          }
          const errPrev = e.state;
          e.state = {
            data: errPrev.data,
            error: err,
            isLoading: false,
            isRefetching: false,
            updatedAt: errPrev.updatedAt
          };
          e.inflight = null;
          this.notify(stringKey);
          throw err;
        });
      cur.inflight = promise as Object as Promise<Object>;
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
        return e.state as Object as QueryState<T>;
      },
      refetch: (): void => { startFetch(true); },
      cancel: (): void => {
        const e = this.entries.get(stringKey);
        e?.cancelToken?.abort();
      },
      unsubscribe: (): void => {
        if (unsubscribed) return;
        unsubscribed = true;
        const e = this.entries.get(stringKey);
        if (!e) return;
        e.observers.delete(observer);
        if (e.observers.size === 0) {
          e.cancelToken?.abort();
          this.entries.delete(stringKey);
        }
      }
    };
  }

  setQueryData<T>(key: QueryKey, data: T | ((prev: T | undefined) => T)): void {
    const stringKey = this.keyOf(key);
    const entry = this.entries.get(stringKey);
    // `state.data` is `QueryState<Object>::data`, so it widens
    // through `Object`. Casting back to `T | undefined` is the
    // call site's responsibility (the call site wrote T in).
    const prev = entry?.state.data as Object as T | undefined;
    const next = typeof data === 'function'
      ? (data as (p: T | undefined) => T)(prev)
      : data;
    if (entry) {
      const setPrev = entry.state;
      entry.state = {
        data: next as Object,
        error: null,
        isLoading: setPrev.isLoading,
        isRefetching: setPrev.isRefetching,
        updatedAt: Date.now()
      };
      this.notify(stringKey);
    } else {
      this.entries.set(stringKey, {
        state: { data: next as Object, error: null, isLoading: false, isRefetching: false, updatedAt: Date.now() },
        cancelToken: null,
        inflight: null,
        staleTimeMs: 0,
        observers: new Set()
      });
      this.notifyGlobal();
    }
  }

  invalidate(key: QueryKey): void {
    this.entries.delete(this.keyOf(key));
    // H-1 fix: page-level @Local mirrors must re-sync after a
    // delete so the UI can drop the now-stale data.
    this.notifyGlobal();
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
    this.notifyGlobal();
  }

  clear(): void {
    for (const entry of this.entries.values()) {
      entry.cancelToken?.abort();
    }
    this.entries.clear();
    this.notifyGlobal();
  }

  // H-1 fix: a global "anything changed" hook so pages can mirror
  // cache state into @Local fields. The per-query onUpdate callback
  // path was unreliable because ArkUI only tracks @Local fields that
  // build() actually reads, and a single callback couldn't guarantee
  // its assignment landed in a slot the build() body referenced. A
  // page subscribes once with `onAnyStateChange(cb)`, the cb reads
  // the relevant cache entries and writes them into @Local mirrors,
  // and the page's build() reads those mirrors — which ArkUI
  // *does* track because the build body references them directly.
  private readonly globalListeners: Set<() => void> = new Set();

  onAnyStateChange(cb: () => void): () => void {
    this.globalListeners.add(cb);
    return () => {
      this.globalListeners.delete(cb);
    };
  }

  private notifyGlobal(): void {
    for (const cb of Array.from(this.globalListeners)) {
      try {
        cb();
      } catch (err) {
        console.warn('[query] global listener threw', err);
      }
    }
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
    this.notifyGlobal();
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
