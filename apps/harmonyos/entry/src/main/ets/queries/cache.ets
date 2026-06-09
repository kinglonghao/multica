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
 */

import { ApiError } from '../data/api';

export interface QueryState<T> {
  data: T | undefined;
  error: Error | null;
  isLoading: boolean;
  isRefetching: boolean;
  updatedAt: number | null;
}

export type QueryKey = readonly unknown[];

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

class QueryClient {
  private readonly entries = new Map<string, InternalEntry<unknown>>();

  private keyOf(key: QueryKey): string {
    return JSON.stringify(key);
  }

  get<T>(key: QueryKey): QueryState<T> | undefined {
    const entry = this.entries.get(this.keyOf(key)) as InternalEntry<T> | undefined;
    return entry?.state;
  }

  subscribe<T>(
    key: QueryKey,
    fetcher: Fetcher<T>,
    options: QueryOptions = {}
  ): QueryHandle<T> {
    const stringKey = this.keyOf(key);
    let entry = this.entries.get(stringKey) as InternalEntry<T> | undefined;
    if (!entry) {
      entry = {
        state: { data: undefined, error: null, isLoading: true, isRefetching: false, updatedAt: null },
        controller: null,
        inflight: null,
        staleTimeMs: options.staleTimeMs ?? 0,
        observers: new Set()
      };
      this.entries.set(stringKey, entry as InternalEntry<unknown>);
    } else {
      entry.staleTimeMs = options.staleTimeMs ?? entry.staleTimeMs;
    }

    // Each call to subscribe adds its own observer so the page that
    // owns this subscription gets a notification on every state change.
    // The observer is the page's `bumpVersion` callback — when fired,
    // the page re-renders, the next `build()` calls `getState()`, and
    // the latest data appears.
    const observer = (): void => {
      if (options.onUpdate) options.onUpdate();
    };
    entry.observers.add(observer);

    const startFetch = (force: boolean): void => {
      const stale = entry!.state.updatedAt === null ||
        Date.now() - entry!.state.updatedAt > entry!.staleTimeMs;
      if (entry!.inflight && !force) return;
      if (!stale && !force && entry!.state.data !== undefined) {
        entry!.state = { ...entry!.state, isLoading: false };
        return;
      }
      const controller = new AbortController();
      entry!.controller?.abort();
      entry!.controller = controller;
      entry!.state = {
        ...entry!.state,
        isLoading: entry!.state.data === undefined,
        isRefetching: entry!.state.data !== undefined,
        error: null
      };
      this.notify(stringKey);
      const promise = fetcher({ signal: controller.signal })
        .then(data => {
          entry!.state = {
            data,
            error: null,
            isLoading: false,
            isRefetching: false,
            updatedAt: Date.now()
          };
          entry!.inflight = null;
          this.notify(stringKey);
          return data;
        })
        .catch((err: Error) => {
          if (err instanceof ApiError && err.status === 0) {
            // Cancellation — keep the prior data, swallow the error.
            entry!.state = { ...entry!.state, isLoading: false, isRefetching: false };
            this.notify(stringKey);
            return undefined as unknown as T;
          }
          entry!.state = {
            ...entry!.state,
            error: err,
            isLoading: false,
            isRefetching: false
          };
          entry!.inflight = null;
          this.notify(stringKey);
          throw err;
        });
      entry!.inflight = promise;
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
        const e = this.entries.get(stringKey) as InternalEntry<T> | undefined;
        return e ? e.state : { data: undefined, error: null, isLoading: true, isRefetching: false, updatedAt: null };
      },
      refetch: (): void => { startFetch(true); },
      cancel: (): void => { entry!.controller?.abort(); },
      unsubscribe: (): void => {
        if (unsubscribed) return;
        unsubscribed = true;
        entry!.observers.delete(observer);
        if (entry!.observers.size === 0) {
          entry!.controller?.abort();
          this.entries.delete(stringKey);
        }
      }
    };
  }

  setQueryData<T>(key: QueryKey, data: T | ((prev: T | undefined) => T)): void {
    const stringKey = this.keyOf(key);
    const entry = this.entries.get(stringKey) as InternalEntry<T> | undefined;
    const next = typeof data === 'function'
      ? (data as (p: T | undefined) => T)(entry?.state.data)
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
      } as InternalEntry<unknown>);
    }
  }

  invalidate(key: QueryKey): void {
    this.entries.delete(this.keyOf(key));
  }

  clear(): void {
    for (const entry of this.entries.values()) {
      entry.controller?.abort();
    }
    this.entries.clear();
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
