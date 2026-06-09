/**
 * Unit tests for the inbox dedup helper. Mirrors the iOS
 * `apps/mobile/lib/inbox-display.test.ts` test surface and the
 * web `packages/core/inbox/queries.ts` `deduplicateInboxItems`
 * behavior.
 *
 * The fix history here matters: on 2026-05-09 the iOS app shipped
 * an inbox that didn't dedup, and the unread dot count drifted
 * from web (1) to mobile (3+). These tests are the regression net
 * that makes sure the HarmonyOS port doesn't reintroduce the bug.
 */
import { describe, it, expect } from '@ohos/hypium';
import { deduplicateInboxItems } from '../../../../main/ets/lib/inbox-display';
import { InboxItem } from '../../../../main/ets/models/types';

const now = '2026-06-09T00:00:00Z';
const earlier = '2026-06-08T22:00:00Z';
const evenEarlier = '2026-06-08T20:00:00Z';

function mkItem(overrides: Partial<InboxItem>): InboxItem {
  return {
    id: 'i-1',
    type: 'mention',
    read: false,
    archived: false,
    workspace_id: 'ws-1',
    created_at: now,
    updated_at: now,
    ...overrides
  };
}

export default function inboxDisplayTest(): void {
  describe('deduplicateInboxItems', () => {
    it('drops archived items', () => {
      const items: InboxItem[] = [
        mkItem({ id: 'a' }),
        mkItem({ id: 'b', archived: true }),
        mkItem({ id: 'c' })
      ];
      const out = deduplicateInboxItems(items);
      expect(out.length).assertEqual(2);
      expect(out.find(i => i.id === 'a')).assertNotEqual(undefined);
      expect(out.find(i => i.id === 'c')).assertNotEqual(undefined);
      expect(out.find(i => i.id === 'b')).assertEqual(undefined);
    });

    it('collapses multiple notifications on the same issue to the newest', () => {
      const items: InboxItem[] = [
        mkItem({ id: 'a', issue_id: 'X-1', created_at: evenEarlier }),
        mkItem({ id: 'b', issue_id: 'X-1', created_at: now }),
        mkItem({ id: 'c', issue_id: 'X-1', created_at: earlier })
      ];
      const out = deduplicateInboxItems(items);
      expect(out.length).assertEqual(1);
      expect(out[0].id).assertEqual('b');
    });

    it('keeps one row per distinct issue', () => {
      const items: InboxItem[] = [
        mkItem({ id: 'a', issue_id: 'X-1', created_at: now }),
        mkItem({ id: 'b', issue_id: 'X-2', created_at: earlier }),
        mkItem({ id: 'c', issue_id: 'X-3', created_at: evenEarlier })
      ];
      const out = deduplicateInboxItems(items);
      expect(out.length).assertEqual(3);
    });

    it('sorts newest-first', () => {
      const items: InboxItem[] = [
        mkItem({ id: 'a', issue_id: 'X-1', created_at: evenEarlier }),
        mkItem({ id: 'b', issue_id: 'X-2', created_at: now }),
        mkItem({ id: 'c', issue_id: 'X-3', created_at: earlier })
      ];
      const out = deduplicateInboxItems(items);
      expect(out[0].id).assertEqual('b');
      expect(out[1].id).assertEqual('c');
      expect(out[2].id).assertEqual('a');
    });

    it('keeps non-issue rows under their own key', () => {
      // An inbox item without issue_id is a solo notification; it
      // should appear once (not collide with other solo items).
      const items: InboxItem[] = [
        mkItem({ id: 'a', issue_id: undefined, created_at: now }),
        mkItem({ id: 'b', issue_id: undefined, created_at: earlier })
      ];
      const out = deduplicateInboxItems(items);
      expect(out.length).assertEqual(2);
    });

    it('combines archive filter, dedup, and sort in one pass', () => {
      const items: InboxItem[] = [
        mkItem({ id: 'a', issue_id: 'X-1', created_at: now }),
        mkItem({ id: 'a-old', issue_id: 'X-1', created_at: evenEarlier, archived: true }),
        mkItem({ id: 'b', issue_id: 'X-2', created_at: earlier }),
        mkItem({ id: 'b-dup', issue_id: 'X-2', created_at: now }),
        mkItem({ id: 'c', issue_id: 'X-3', created_at: evenEarlier, archived: true })
      ];
      const out = deduplicateInboxItems(items);
      expect(out.length).assertEqual(2);
      // b-dup is newer than b for X-2; expect b-dup to win.
      expect(out[0].id).assertEqual('b-dup');
      expect(out[1].id).assertEqual('a');
    });
  });
}
