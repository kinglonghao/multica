import { InboxItem } from '../models/types';

/**
 * Deduplicate inbox items, mirroring `packages/core/inbox/queries.ts`
 * `deduplicateInboxItems` and `apps/mobile/lib/inbox-display.ts`.
 *
 * ⚠️ Behavioral parity hazard (see apps/mobile/CLAUDE.md "Behavioral
 * parity → Inbox dedup incident 2026-05-09"): the backend `GET /api/inbox`
 * returns raw rows that include (a) archived items and (b) multiple
 * notifications per issue (a comment + a status change + an assignment on
 * the same issue each create one row). Web runs the raw rows through
 * `deduplicateInboxItems` before rendering and before counting unread.
 * Mobile must mirror exactly or the unread-dot count drifts.
 *
 * Algorithm:
 * 1. Filter out `archived = true`.
 * 2. Group by `issue_id` (or `id` for non-issue items), keep the newest
 *    in each group.
 * 3. Sort by `created_at` desc.
 */
export function deduplicateInboxItems(items: InboxItem[]): InboxItem[] {
  const visible = items.filter(i => !i.archived);
  const groups = new Map<string, InboxItem>();
  for (const item of visible) {
    const key = item.issue_id ?? `solo:${item.id}`;
    const existing = groups.get(key);
    if (!existing || new Date(item.created_at).getTime() > new Date(existing.created_at).getTime()) {
      groups.set(key, item);
    }
  }
  return Array.from(groups.values()).sort(
    (a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );
}
