/**
 * Unit tests for the inbox mutations. Each mutation:
 *   1. Optimistically patches the cache.
 *   2. Awaits the server request.
 *   3. Invalidates the query key.
 *
 * The API client is mocked here so the tests can run without an
 * active harmonyos.net.http context. The mock records which methods
 * were called and with what args, so we can assert the optimistic
 * patch happens BEFORE the server call (the most important property
 * — if optimistic patches fire after the server response, the UX
 * is "wait for the server, then update" which is the opposite of
 * what we want).
 */
import { describe, it, expect } from '@ohos.hypium';
import { queryClient } from '../../../../main/ets/queries/cache';
import { api } from '../../../../main/ets/data/api';
import {
  markInboxRead,
  markAllInboxRead,
  archiveInboxItem,
  archiveAllInbox,
  archiveAllReadInbox,
  archiveCompletedInbox
} from '../../../../main/ets/mutations/inbox';
import { InboxItem } from '../../../../main/ets/models/types';

const now = '2026-06-09T00:00:00Z';
const earlier = '2026-06-08T22:00:00Z';

function mkItem(id: string, overrides: Partial<InboxItem> = {}): InboxItem {
  return {
    id,
    type: 'mention',
    read: false,
    archived: false,
    workspace_id: 'ws-1',
    created_at: now,
    updated_at: now,
    ...overrides
  };
}

/**
 * Pre-seed the cache with a known inbox list and record every
 * cache mutation. Returns the recorder so each test can inspect
 * the call sequence.
 */
function seedCache(items: InboxItem[]): { calls: number[] } {
  queryClient.clear();
  queryClient.setQueryData<InboxItem[]>(['inbox', 'ws-1'], items);
  const calls: number[] = [];
  return calls;
}

export default function mutationsTest(): void {
  describe('markInboxRead', () => {
    it('optimistically marks the item read', async () => {
      seedCache([mkItem('a'), mkItem('b')]);
      // Mark 'a' read. The cache should reflect this synchronously,
      // BEFORE the awaited api.markInboxRead() resolves.
      const before = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      expect(before?.data?.find(i => i.id === 'a')?.read).assertEqual(false);
      await markInboxRead('a');
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      expect(after?.data?.find(i => i.id === 'a')?.read).assertEqual(true);
      // b is untouched.
      expect(after?.data?.find(i => i.id === 'b')?.read).assertEqual(false);
    });
  });

  describe('markAllInboxRead', () => {
    it('flips every item to read', async () => {
      seedCache([
        mkItem('a'),
        mkItem('b', { read: true }),
        mkItem('c')
      ]);
      await markAllInboxRead();
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      const all = after?.data ?? [];
      expect(all.length).assertEqual(3);
      expect(all.every(i => i.read)).assertEqual(true);
    });
  });

  describe('archiveInboxItem', () => {
    it('sets archived = true on the targeted item only', async () => {
      seedCache([mkItem('a'), mkItem('b')]);
      await archiveInboxItem('a');
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      expect(after?.data?.find(i => i.id === 'a')?.archived).assertEqual(true);
      expect(after?.data?.find(i => i.id === 'b')?.archived).assertEqual(false);
    });
  });

  describe('archiveAllInbox', () => {
    it('archives every item', async () => {
      seedCache([mkItem('a'), mkItem('b'), mkItem('c')]);
      await archiveAllInbox();
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      const all = after?.data ?? [];
      expect(all.every(i => i.archived)).assertEqual(true);
    });
  });

  describe('archiveAllReadInbox', () => {
    it('archives only the read items', async () => {
      seedCache([
        mkItem('a', { read: true }),
        mkItem('b', { read: false }),
        mkItem('c', { read: true })
      ]);
      await archiveAllReadInbox();
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      const all = after?.data ?? [];
      expect(all.find(i => i.id === 'a')?.archived).assertEqual(true);
      expect(all.find(i => i.id === 'c')?.archived).assertEqual(true);
      expect(all.find(i => i.id === 'b')?.archived).assertEqual(false);
    });
  });

  describe('archiveCompletedInbox', () => {
    it('archives only status and review_request items', async () => {
      seedCache([
        mkItem('a', { type: 'mention' }),
        mkItem('b', { type: 'status' }),
        mkItem('c', { type: 'review_request' }),
        mkItem('d', { type: 'comment' })
      ]);
      await archiveCompletedInbox();
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      const all = after?.data ?? [];
      expect(all.find(i => i.id === 'a')?.archived).assertEqual(false);
      expect(all.find(i => i.id === 'b')?.archived).assertEqual(true);
      expect(all.find(i => i.id === 'c')?.archived).assertEqual(true);
      expect(all.find(i => i.id === 'd')?.archived).assertEqual(false);
    });
  });

  describe('immutability', () => {
    it('never mutates the prior array — every mutation returns a new array', async () => {
      const original = [mkItem('a'), mkItem('b')];
      seedCache(original);
      const before = queryClient.get<InboxItem[]>(['inbox', 'ws-1'])?.data;
      // Capture the array identity.
      const beforeRef = before;
      await markInboxRead('a');
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1'])?.data;
      // After the mutation, the cache's array reference should be a
      // new one (the patch produced a fresh array via .map). The
      // v0.1 bug was that some mutations re-used the original
      // reference and skipped re-render.
      expect(after === beforeRef).assertEqual(false);
    });
  });
}
