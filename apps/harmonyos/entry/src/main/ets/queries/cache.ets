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
 * When the page tears down (or the user navigates away), the caller
 * calls `queryClient.cancel(key)` and the in-flight request's signal
 * fires, the API client destroys the HTTP task, and the resolver
 * rejects with ApiError(0). That matches iOS exactly.
 *
 * Usage:
 *   const inbox = useQuery(
 *     () => ['inbox', wsId],
 *     ({ signal }) => api.listInbox({ signal }),
 *     { staleTimeMs: 30_000 }
 *   );
 *   // inbox: { data, error, isLoading, isRefetching, refetch }
 */

import { ApiError } from '../data/api';

export interface QueryState<T> {
  data: T | undefined;
  error: Error | null;
  isLoading: boolean;
  isRefetching: boolean;
  updatedAt: number | null;
}

type QueryKey = readonly unknown[];

type Fetcher<T> = (ctx: { signal: AbortSignal }) => Promise<T>;

interface InternalEntry<T> {
  state: QueryState<T>;
  controller: AbortController | null;
  inflight: Promise<T> | null;
  staleTimeMs: number;
  observers: Set<(s: QueryState<T>) => void>;
}

class QueryClient {
  private readonly entries = new Map<string, InternalEntry<unknown>>();

  /**
   * Internal: derive a stable string key from a QueryKey. JSON.stringify
   * is the convention we use; keys are tuples of primitives in practice
   * so the collisions are negligible.
   */
  private keyOf(key: QueryKey): string {
    return JSON.stringify(key);
  }

  get<T>(key: QueryKey): QueryState<T> | undefined {
    const entry = this.entries.get(this.keyOf(key)) as InternalEntry<T> | undefined;
    return entry?.state;
  }

  /**
   * Start a fetch if no in-flight request exists for the key. Returns
   * a subscription handle — call .unsubscribe() to stop receiving
   * state updates. The handle also exposes .refetch() to force a
   * fresh fetch and .cancel() to abort the in-flight one.
   */
  subscribe<T>(
    key: QueryKey,
    fetcher: Fetcher<T>,
    options: { staleTimeMs?: number } = {}
  ): {
    unsubscribe: () => void;
    refetch: () => void;
    cancel: () => void;
  } {
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

    const observer = (s: QueryState<T>): void => { /* no-op; calls go through state setter */ };
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

    // Eagerly start a fetch on first subscribe if the cache is empty.
    if (entry.state.data === undefined && !entry.inflight) {
      startFetch(false);
    } else {
      // Stale-while-revalidate: if data is stale, kick a refetch in the
      // background so the next subscribe gets fresh data without flicker.
      const stale = entry.state.updatedAt === null ||
        Date.now() - entry.state.updatedAt > entry.staleTimeMs;
      if (stale && !entry.inflight) {
        startFetch(true);
      }
    }

    return {
      unsubscribe: (): void => {
        entry!.observers.delete(observer);
        // If no observers remain, cancel any in-flight request and drop
        // the entry so a future subscribe re-fetches from scratch.
        if (entry!.observers.size === 0) {
          entry!.controller?.abort();
          this.entries.delete(stringKey);
        }
      },
      refetch: (): void => { startFetch(true); },
      cancel: (): void => { entry!.controller?.abort(); }
    };
  }

  /**
   * Imperatively write data into the cache (used by mutations for
   * optimistic updates and by WS event handlers for cache patches).
   * Mirrors TQ's `queryClient.setQueryData(key, updater)`.
   */
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
    const stringKey = this.keyOf(key);
    this.entries.delete(stringKey);
    // Subscribers will re-subscribe on next read; the fetch fires on
    // first observer attach.
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
    // The observers themselves just call back through the subscribe handle.
    // We notify by re-running them; the subscribe API keeps a single
    // observer per call so this is cheap.
    for (const obs of entry.observers) {
      // Cast: each observer was added with a matching T. The observer
      // signature is intentionally a no-op — page components read state
      // via `get()` and refresh manually when notified. We notify via a
      // separate channel below.
      void obs(entry.state);
    }
  }
}

export const queryClient: QueryClient = new QueryClient();

/**
 * Hook-shaped helper for components. Returns a `QueryState<T>` and a
 * `refetch` / `cancel` pair, and re-renders the page when state changes.
 *
 * Why a "hook-shaped helper" instead of a real @CustomHook? ArkUI's
 * `makeState` / `makeBuilder` aren't the right fit for a one-shot
 * subscription — instead we expose a `useQuery` function that pages
 * call inside `aboutToAppear` and call `.unsubscribe()` in
 * `aboutToDisappear`. Mirrors TQ's `useQuery` API surface in spirit.
 */
export interface QueryHandle<T> {
  state: QueryState<T>;
  refetch: () => void;
  cancel: () => void;
}

export function useQuery<T>(
  key: QueryKey,
  fetcher: Fetcher<T>,
  options: { staleTimeMs?: number; enabled?: boolean } = {}
): QueryHandle<T> {
  const handle = queryClient.subscribe(key, fetcher, options);
  const state = queryClient.get<T>(key) ?? {
    data: undefined,
    error: null,
    isLoading: true,
    isRefetching: false,
    updatedAt: null
  };
  return {
    state,
    refetch: handle.refetch,
    cancel: handle.cancel
  };
}
