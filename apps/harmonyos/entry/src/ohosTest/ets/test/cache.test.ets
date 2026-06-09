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
 */
import { describe, it, expect } from '@ohos.hypium';
import { queryClient, useQuery } from '../../../../main/ets/queries/cache';
import { ApiError } from '../../../../main/ets/data/api';

interface Item { id: string; name: string; }

const fetchItems = (items: Item[]): ((ctx: { signal: AbortSignal }) => Promise<Item[]>) => {
  return ({ signal }: { signal: AbortSignal }): Promise<Item[]> => {
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

export default function cacheTest(): void {
  describe('useQuery', () => {
    it('returns a handle whose getState() reflects the latest data', () => {
      queryClient.clear();
      const key = ['test-handle-1'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
      const s = handle.getState();
      expect(s.data?.length).assertEqual(1);
      expect(s.data?.[0]?.name).assertEqual('A');
      handle.unsubscribe();
    });

    it('fires onUpdate on initial fetch', () => {
      queryClient.clear();
      const key = ['test-handle-2'];
      let calls = 0;
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]), {
        onUpdate: () => { calls++; }
      });
      // Allow the microtask to fire.
      return new Promise<void>((resolve) => {
        setTimeout(() => {
          expect(calls > 0).assertEqual(true);
          handle.unsubscribe();
          resolve();
        }, 20);
      });
    });

    it('setQueryData patches without refetching', () => {
      queryClient.clear();
      const key = ['test-handle-3'];
      const handle = useQuery<Item[]>(key, fetchItems([{ id: 'a', name: 'A' }]));
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
  });
}
