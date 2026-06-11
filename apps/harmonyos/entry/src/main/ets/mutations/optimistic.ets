import { queryClient, QueryKey } from '../queries/cache';
import { ApiError } from '../data/api';

/**
 * Optimistic mutation helper.
 *
 * Mirrors the lifecycle that TanStack Query's `useMutation` encodes on
 * web/mobile (`onMutate` → `mutationFn` → `onSuccess` / `onError` →
 * `onSettled`) but reduced to the four phases we need on HarmonyOS:
 *
 *   1. **Snapshot** — capture the current cache value(s) for the keys
 *      the mutation will touch, so we can roll back on failure.
 *   2. **Optimistic patch** — apply the user's expected outcome to
 *      the cache (setQueryData with a function) BEFORE awaiting the
 *      network call. The UI flips instantly.
 *   3. **Server settle** — call `request()`. On success, write the
 *      server's authoritative response back into the cache (if the
 *      caller supplied a setter) and run the settle invalidate so
 *      list caches refetch. On failure, roll back to the snapshot.
 *   4. **Cancellation safety** — a 0-status ApiError (request was
 *      aborted or timed out) does NOT roll back: the next refetch
 *      will reconcile, and rolling back an in-flight optimistic
 *      patch would briefly show a worse value than the cache
 *      already had.
 *
 * Why a shared helper: every mutation module in this app follows the
 * same shape (setQueryData + send + rollback + invalidate). Keeping
 * the shape in one place means new mutations can't forget the
 * rollback path, and the cache's `invalidatePrefix` calls don't get
 * out of sync with the keys a real mutation touches.
 *
 * What it does NOT do:
 *   - It does NOT handle the "user already navigated away" case.
 *     After a mutation settles the cache still gets the new value,
 *     and the next mount of the page will see it. If you need a
 *     hard unsubscribe-then-rollback path (e.g. an unmount during
 *     a long file upload), handle it in the caller.
 *   - It does NOT manage the per-key AbortController. Mutations
 *     are one-shot; the cache `cancel()` is the caller's call.
 */
export interface OptimisticOptions<TPatch, TResponse, TRollback> {
  /**
   * One or more cache keys whose `data` field the optimistic patch
   * will touch. A `readonly` tuple is accepted so callers can pass
   * the same key factory result they use elsewhere.
   */
  keys: ReadonlyArray<QueryKey>;
  /**
   * Apply the optimistic patch to each key's data. The setter is
   * called once per key (in the order they were declared) BEFORE
   * the request is sent. Return a value to be passed back to
   * `rollback` if the request fails.
   */
  apply: () => TRollback;
  /**
   * The actual server call. Runs after `apply` resolves.
   */
  request: () => Promise<TResponse>;
  /**
   * Restore the prior cache state for each key. Called only on
   * failure (non-abort). Receives whatever `apply` returned.
   */
  rollback: (snapshot: TRollback) => void;
  /**
   * Optional hook for writing the server's authoritative response
   * back into the cache (e.g. replacing a temp `id: 'temp-…'`
   * placeholder with the real server id). Runs on success only.
   */
  onSuccess?: (response: TResponse) => void;
  /**
   * Optional list-key prefix to invalidate after settle (success OR
   * failure). Use this when the mutation may have changed the shape
   * of a list cache (e.g. a status flip that should re-rank
   * `issues:list` rows).
   */
  settleInvalidatePrefixes?: ReadonlyArray<QueryKey>;
}

export interface OptimisticResult<TResponse> {
  response: TResponse | undefined;
  /**
   * True if the mutation failed AND the optimistic patch was rolled
   * back. False for success, for "aborted" 0-status ApiErrors, and
   * for plain throws the caller may want to inspect themselves.
   */
  rolledBack: boolean;
}

export async function runOptimistic<TPatch, TResponse, TRollback>(
  opts: OptimisticOptions<TPatch, TResponse, TRollback>
): Promise<OptimisticResult<TResponse>> {
  const snapshot = opts.apply();
  try {
    const response = await opts.request();
    if (opts.onSuccess) opts.onSuccess(response);
    if (opts.settleInvalidatePrefixes) {
      for (const p of opts.settleInvalidatePrefixes) queryClient.invalidatePrefix(p);
    }
    return { response, rolledBack: false };
  } catch (err) {
    // Don't roll back on abort/timeout — the cache may not even
    // have an entry yet, and a hard rollback on a cancellation
    // races the next refetch the caller will trigger.
    if (err instanceof ApiError && err.status === 0) {
      if (opts.settleInvalidatePrefixes) {
        for (const p of opts.settleInvalidatePrefixes) queryClient.invalidatePrefix(p);
      }
      throw err;
    }
    opts.rollback(snapshot);
    if (opts.settleInvalidatePrefixes) {
      for (const p of opts.settleInvalidatePrefixes) queryClient.invalidatePrefix(p);
    }
    return { response: undefined, rolledBack: true };
  }
}

/**
 * Shorthand for the "mutate a single cache entry" case. The most
 * common usage in this app: the mutation has a known detail-key, the
 * optimistic patch is a function over the prior value, and the
 * rollback is the inverse. Use `runOptimistic` directly when a
 * mutation needs to touch more than one key.
 */
export async function mutateDetail<T>(
  key: QueryKey,
  patch: (prev: T | undefined) => T | undefined,
  request: () => Promise<T>,
  settleInvalidatePrefixes?: ReadonlyArray<QueryKey>
): Promise<T> {
  const result = await runOptimistic<unknown, T, T | undefined>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<T>(key)?.data;
      const next = patch(prior);
      if (next !== undefined) {
        queryClient.setQueryData<T>(key, next);
      }
      return prior;
    },
    request,
    rollback: (prior) => {
      if (prior === undefined) {
        queryClient.invalidate(key);
      } else {
        queryClient.setQueryData<T>(key, prior);
      }
    },
    onSuccess: (response) => {
      queryClient.setQueryData<T>(key, response);
    },
    settleInvalidatePrefixes
  });
  if (result.rolledBack) {
    throw new Error('Mutation rolled back');
  }
  if (result.response === undefined) {
    throw new Error('Mutation aborted');
  }
  return result.response;
}
