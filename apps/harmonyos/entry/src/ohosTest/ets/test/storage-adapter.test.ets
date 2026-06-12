/**
 * Unit tests for the persistent cache storage adapter.
 *
 * The actual `@ohos.data.preferences` store requires a UIAbility
 * context to open, which is not available in the unit-test
 * runner. These tests cover the noop fallback (the default
 * before `setStorageAdapter` is called) and the public surface
 * — the disk-backed adapter is exercised by the harmonyos-smoke
 * CI job (J1) on a real device build.
 */
import { describe, it, expect } from '@ohos.hypium';
import { getStorageAdapter, setStorageAdapter } from '../../../../main/ets/queries/storage-adapter';

export default function storageAdapterTest(): void {
  describe('noop storage adapter', () => {
    it('returns undefined for any key before init', async () => {
      // Make sure we start from the noop.
      await setStorageAdapter(null);
      const a = getStorageAdapter();
      const out = await a.load<unknown>('any-key');
      expect(out).assertEqual(undefined);
    });

    it('does not throw on saveAll / clear / close', async () => {
      const a = getStorageAdapter();
      a.saveAll(new Map());
      // clear() / close() are noop on the noop adapter — they
      // still return a resolved Promise.
      await a.clear();
      await a.close();
    });
  });
}
