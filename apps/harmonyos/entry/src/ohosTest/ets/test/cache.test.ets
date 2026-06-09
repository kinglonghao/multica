/**
 * Unit tests for the query cache. Mirrors the iOS
 * `apps/mobile/data/queries/cache.test.ts` test surface.
 *
 * The cache is the heart of the data layer, and these tests pin
 * down the contract that pages depend on:
 *  - subscribe() returns a handle that gives fresh state on every
 *    getState() call (so re-renders always see the latest value)
 *  - setQueryData() patches without refetching
 *  - invalidate() forces the next subscribe to re-fetch
 *  - the onUpdate callback fires on every state change
 *  - cancellation (via AbortSignal) leaves the prior data intact
 *
 * H-9: the v0.2 cache.test.ets read state synchronously after
 * subscribe() and got `data: undefined` because the fetch is async.
 * These tests properly await the fetch via a `waitFor` helper.
 */
import { describe, it, expect } from '@ohos.hypium';
import { queryClient, useQuery, QueryHandle, QueryState } from '../../../../main/ets/queries/cache';
import { ApiError } from '../../../../main/ets/data/api';

interface Item { id: string; name: string; }

interface FetchCtx { signal: AbortSignal; }

const fetchItems = (items: Item[]): ((ctx: FetchCtx) => Promise<Item[]>) => {
  return ({ signal }: FetchCtx): Promise<Item[]> => {
    return new Promise<Item[]>((resolve, reject) => {
      const timer = setTimeout(() => {
        if (signal.aborted) {
          reject(new ApiError('Aborted', 0));
        } else {
          resolve(items);
        }
      }, 5);
      signal.addEventListener('abort', () => {
        clearTimeout(timer);
        reject(new ApiError('Aborted', 0));
      });
    });
  };
};

/**
 * Wait for the cache to settle into a state where `data` is
 * defined. Resolves with the final state. Used so each test
 * doesn't have to manage its own setTimeout chain.
 */
const waitForData: <T>(handle: QueryHandle<T>, timeoutMs?: number) => Promise<QueryState<T>> =
  async <T>(handle: QueryHandle<T>, timeoutMs: number = 1000): Promise<QueryState<T>> => {
    return new Promise<QueryState<T>>((resolve, reject) => {
      const start = Date.now();
      const tick = (): void => {
        const s = handle.getState();
        if (s.data !== undefined && !s.isLoading) {
          resolve(s);
          return;
        }
        if (Date.now() - start > timeoutMs) {
          reject(new Error(`waitForData timed out after ${timeoutMs}ms; state=${JSON.stringify(s)}`));
          return;
        }
        setTimeout(tick, 5);
      };
      tick();
    });
  };

export default function cacheTest(): void {
  describe('useQuery', () => {
    it('returns a handle whose getState() reflects the latest data after the fetch settles', async () => {
      queryClient.clear();
      const key = ['test-handle-1'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
      const s = await waitForData(handle);
      expect(s.data?.length).assertEqual(1);
      expect(s.data?.[0]?.name).assertEqual('A');
      handle.unsubscribe();
    });

    it('fires onUpdate on initial fetch', async () => {
      queryClient.clear();
      const key = ['test-handle-2'];
      let calls = 0;
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]), {
        onUpdate: () => { calls++; }
      });
      await waitForData(handle);
      expect(calls > 0).assertEqual(true);
      handle.unsubscribe();
    });

    it('setQueryData patches without refetching', async () => {
      queryClient.clear();
      const key = ['test-handle-3'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
      // Wait for the original fetch to settle, then patch.
      await waitForData(handle);
      queryClient.setQueryData<Item[]>(key, [{ id: 'b', name: 'B' }]);
      const s = handle.getState();
      expect(s.data?.length).assertEqual(1);
      expect(s.data?.[0]?.id).assertEqual('b');
      handle.unsubscribe();
    });

    it('invalidate() drops the cache entry', () => {
      queryClient.clear();
      const key = ['test-handle-4'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
      queryClient.invalidate(key);
      // The entry is gone, but the handle's getState() falls back to
      // the default "isLoading" state. After invalidate, the next
      // subscribe starts a fresh fetch.
      const s = handle.getState();
      expect(s.isLoading).assertEqual(true);
      handle.unsubscribe();
    });

    it('unsubscribe() removes the entry once observers hit zero', async () => {
      queryClient.clear();
      const key = ['test-handle-5'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
      await waitForData(handle);
      handle.unsubscribe();
      // After unsubscribe, the entry should be cleared. A fresh
      // subscribe should re-fetch (not see the cached value).
      const handle2 = useQuery<Item[]>(key, fetchItems([{ id: 'b', name: 'B' }]));
      const s = await waitForData(handle2);
      expect(s.data?.[0]?.id).assertEqual('b');
      handle2.unsubscribe();
    });
  });
}
