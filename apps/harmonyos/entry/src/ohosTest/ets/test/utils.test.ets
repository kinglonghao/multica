/**
 * Unit tests for the time-ago helper. Mirrors the iOS
 * `apps/mobile/lib/time-ago.test.ts` test surface. The formatter
 * has subtle rules for "just now", future timestamps, and the
 * gap-thresholds between minutes / hours / days, and these
 * tests pin the behavior down so a future refactor doesn't
 * silently shift what the user sees.
 */
import { describe, it, expect } from '@ohos.hypium';
import { timeAgo, cn } from '../../../../main/ets/lib/utils';

export default function utilsTest(): void {
  describe('timeAgo', () => {
    it('returns empty string for null/undefined', () => {
      expect(timeAgo(null)).assertEqual('');
      expect(timeAgo(undefined)).assertEqual('');
    });

    it('returns the raw input when it is unparseable', () => {
      expect(timeAgo('not-a-date')).assertEqual('not-a-date');
    });

    it('renders "just now" for sub-45-second deltas', () => {
      const now = new Date();
      const out = timeAgo(now);
      expect(out).assertEqual('just now');
    });

    it('renders "Xm ago" for sub-hour deltas', () => {
      const t = new Date(Date.now() - 5 * 60 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('5m ago');
    });

    it('renders "Xh ago" for sub-day deltas', () => {
      const t = new Date(Date.now() - 3 * 60 * 60 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('3h ago');
    });

    it('renders "Xd ago" for sub-month deltas', () => {
      const t = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('5d ago');
    });

    it('renders "Xmo ago" for sub-year deltas', () => {
      const t = new Date(Date.now() - 90 * 24 * 60 * 60 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('3mo ago');
    });

    it('renders "Xy ago" for multi-year deltas', () => {
      const t = new Date(Date.now() - 3 * 365 * 24 * 60 * 60 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('3y ago');
    });

    it('renders "in a moment" for small future timestamps', () => {
      const t = new Date(Date.now() + 10 * 1000);
      const out = timeAgo(t);
      expect(out).assertEqual('in a moment');
    });
  });

  describe('cn', () => {
    it('joins truthy strings with single spaces', () => {
      expect(cn('a', 'b', 'c')).assertEqual('a b c');
    });

    it('drops falsy values', () => {
      expect(cn('a', false, null, undefined, 'b')).assertEqual('a b');
    });

    it('returns empty string for all-falsy input', () => {
      expect(cn(false, null, undefined)).assertEqual('');
    });
  });
}
