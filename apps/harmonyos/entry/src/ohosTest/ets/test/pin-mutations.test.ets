/**
 * Unit tests for the pin mutations. Mirrors the iOS
 * `apps/mobile/data/mutations/pin.test.ts` test surface.
 */
import { describe, it, expect, beforeEach } from '@ohos.hypium';
import { queryClient } from '../../../../main/ets/queries/cache';
import { api } from '../../../../main/ets/data/api';
import { addPin, removePin, reorderPins } from '../../../../main/ets/mutations/pin';
import { PinnedItem } from '../../../../main/ets/models/types';

const mkPin = (overrides: Partial<PinnedItem>): PinnedItem => ({
  id: 'pin-1', type: 'issue', workspace_id: 'ws-1', position: 0,
  item_id: 'iss-1', item: null,
  created_at: '2026-06-09T00:00:00Z',
  ...overrides
});

function seedPins(items: PinnedItem[]): void {
  queryClient.clear();
  queryClient.setQueryData<PinnedItem[]>(['pins', 'ws-1'], items);
}

export default function pinMutationsTest(): void {
  beforeEach(() => {
    queryClient.clear();
  });

  describe('addPin', () => {
    it('optimistically appends a placeholder then replaces with server response', async () => {
      seedPins([mkPin({ id: 'existing' })]);
      // Stub the API so we don't hit the network.
      const orig = api.addPin;
      (api as unknown as { addPin: typeof orig }).addPin = async (id: string, t: 'issue' | 'project' | 'doc') => {
        return mkPin({ id: 'pin-new', item_id: id, type: t, position: 1 });
      };
      try {
        const out = await addPin('iss-99', 'issue');
        expect(out.id).assertEqual('pin-new');
        const after = queryClient.get<PinnedItem[]>(['pins', 'ws-1']);
        expect(after?.data?.find(p => p.id === 'pin-new')?.item_id).assertEqual('iss-99');
      } finally {
        (api as unknown as { addPin: typeof orig }).addPin = orig;
      }
    });
  });

  describe('removePin', () => {
    it('removes the pin from the cache', async () => {
      seedPins([mkPin({ id: 'pin-1' }), mkPin({ id: 'pin-2' })]);
      const orig = api.removePin;
      (api as unknown as { removePin: typeof orig }).removePin = async () => { /* noop */ };
      try {
        await removePin('pin-1');
        const after = queryClient.get<PinnedItem[]>(['pins', 'ws-1']);
        expect(after?.data?.find(p => p.id === 'pin-1')).assertEqual(undefined);
        expect(after?.data?.find(p => p.id === 'pin-2')).assertNotEqual(undefined);
      } finally {
        (api as unknown as { removePin: typeof orig }).removePin = orig;
      }
    });
  });

  describe('reorderPins', () => {
    it('optimistically re-sorts by the new id order', async () => {
      seedPins([
        mkPin({ id: 'a', position: 0 }),
        mkPin({ id: 'b', position: 1 }),
        mkPin({ id: 'c', position: 2 })
      ]);
      const orig = api.reorderPins;
      (api as unknown as { reorderPins: typeof orig }).reorderPins = async (req) => {
        return req.pinned_ids.map((id, idx) => mkPin({ id, position: idx }));
      };
      try {
        const out = await reorderPins({ pinned_ids: ['c', 'a', 'b'] });
        expect(out.map(p => p.id)).assertEqual(['c', 'a', 'b']);
        const after = queryClient.get<PinnedItem[]>(['pins', 'ws-1']);
        expect(after?.data?.map(p => p.id)).assertEqual(['c', 'a', 'b']);
      } finally {
        (api as unknown as { reorderPins: typeof orig }).reorderPins = orig;
      }
    });
  });
}
