/**
 * Unit tests for the read-path utility library. Mirrors the
 * iOS `apps/mobile/lib/format-elapsed.test.ts` and
 * `failure-reason-label.test.ts` test surfaces. The formatters
 * have non-obvious rules (e.g. "<$0.01" threshold, "Failed"
 * fallback for unknown enum values) and the tests pin them
 * down so a refactor can't silently shift what the user sees.
 */
import { describe, it, expect } from '@ohos.hypium';
import {
  formatElapsedSecs,
  formatElapsedMs,
  shortDate,
  failureReasonLabel,
  truncate,
  stableKeyForObject,
  firstDefined,
  nonEmpty,
  formatCostUsd
} from '../../../../main/ets/lib/format-utils';

export default function formatUtilsTest(): void {
  describe('formatElapsedSecs', () => {
    it('renders sub-minute durations as "Xs"', () => {
      expect(formatElapsedSecs(0)).assertEqual('0s');
      expect(formatElapsedSecs(1)).assertEqual('1s');
      expect(formatElapsedSecs(38)).assertEqual('38s');
      expect(formatElapsedSecs(59)).assertEqual('59s');
    });

    it('renders sub-hour durations as "Xm" or "Xm Ys"', () => {
      expect(formatElapsedSecs(60)).assertEqual('1m');
      expect(formatElapsedSecs(125)).assertEqual('2m 5s');
      expect(formatElapsedSecs(3599)).assertEqual('59m 59s');
    });

    it('clamps negative / non-finite inputs to "0s"', () => {
      expect(formatElapsedSecs(-1)).assertEqual('0s');
      expect(formatElapsedSecs(NaN)).assertEqual('0s');
      expect(formatElapsedSecs(Infinity)).assertEqual('0s');
    });
  });

  describe('formatElapsedMs', () => {
    it('converts milliseconds to the same buckets', () => {
      expect(formatElapsedMs(0)).assertEqual('0s');
      expect(formatElapsedMs(5_000)).assertEqual('5s');
      expect(formatElapsedMs(60_000)).assertEqual('1m');
      expect(formatElapsedMs(125_000)).assertEqual('2m 5s');
    });

    it('clamps negative milliseconds to "0s"', () => {
      expect(formatElapsedMs(-100)).assertEqual('0s');
    });
  });

  describe('shortDate', () => {
    it('returns "?" for null / undefined / empty', () => {
      expect(shortDate(null)).assertEqual('?');
      expect(shortDate(undefined)).assertEqual('?');
      expect(shortDate('')).assertEqual('?');
    });

    it('renders YYYY-MM-DD as "Mon D"', () => {
      expect(shortDate('2024-06-12')).assertEqual('Jun 12');
      expect(shortDate('2024-01-01')).assertEqual('Jan 1');
      expect(shortDate('2024-12-31')).assertEqual('Dec 31');
    });

    it('includes the year when the date is not in the current year', () => {
      expect(shortDate('2020-06-12')).assertEqual('Jun 12, 2020');
    });

    it('strips the time component from full RFC3339 strings', () => {
      expect(shortDate('2024-06-12T10:30:00Z')).assertEqual('Jun 12');
    });

    it('returns the raw input for unparseable shapes', () => {
      expect(shortDate('not-a-date')).assertEqual('not-a-date');
      expect(shortDate('2024-13-99')).assertEqual('2024-13-99');
    });
  });

  describe('failureReasonLabel', () => {
    it('maps known reasons to user-friendly labels', () => {
      expect(failureReasonLabel('timeout')).assertEqual('Timed out');
      expect(failureReasonLabel('auth')).assertEqual('Authentication failed');
      expect(failureReasonLabel('rate_limit')).assertEqual('Rate limited');
      expect(failureReasonLabel('crash')).assertEqual('Crashed');
      expect(failureReasonLabel('user_abort')).assertEqual('Cancelled by user');
      expect(failureReasonLabel('unknown')).assertEqual('Failed');
    });

    it('falls through to a generic "Failed" for unknown values', () => {
      expect(failureReasonLabel('oops_new_thing')).assertEqual('Failed');
    });

    it('returns "Failed" for null / undefined', () => {
      expect(failureReasonLabel(null)).assertEqual('Failed');
      expect(failureReasonLabel(undefined)).assertEqual('Failed');
    });
  });

  describe('truncate', () => {
    it('returns the input unchanged when under the max', () => {
      expect(truncate('hi', 10)).assertEqual('hi');
    });

    it('appends an ellipsis when over the max', () => {
      expect(truncate('hello world', 6)).assertEqual('hello…');
    });

    it('returns empty for null / undefined / empty input', () => {
      expect(truncate(null, 10)).assertEqual('');
      expect(truncate(undefined, 10)).assertEqual('');
      expect(truncate('', 10)).assertEqual('');
    });

    it('handles a max of 1 without crashing', () => {
      expect(truncate('hello', 1)).assertEqual('h');
    });
  });

  describe('stableKeyForObject', () => {
    it('serialises a flat object with sorted keys', () => {
      const key = stableKeyForObject({ b: 1, a: 2 });
      expect(key).assertEqual('a=2&b=1');
    });

    it('skips null / undefined / empty-array values', () => {
      const key = stableKeyForObject({ a: 1, b: null, c: undefined, d: [] });
      expect(key).assertEqual('a=1');
    });

    it('sorts array values for deterministic keying', () => {
      const a = stableKeyForObject({ tags: ['b', 'a', 'c'] });
      const b = stableKeyForObject({ tags: ['c', 'a', 'b'] });
      expect(a).assertEqual(b);
    });

    it('returns empty for null / undefined', () => {
      expect(stableKeyForObject(null)).assertEqual('');
      expect(stableKeyForObject(undefined)).assertEqual('');
    });
  });

  describe('firstDefined', () => {
    it('returns the first non-null / non-undefined value', () => {
      expect(firstDefined(null, undefined, 'first', 'second')).assertEqual('first');
    });

    it('returns undefined when every input is nullish', () => {
      expect(firstDefined(null, undefined, null)).assertEqual(undefined);
    });

    it('treats 0 / "" / false as defined', () => {
      expect(firstDefined(0, 1)).assertEqual(0);
      expect(firstDefined('', 'x')).assertEqual('');
    });
  });

  describe('nonEmpty', () => {
    it('returns the trimmed string for non-empty input', () => {
      expect(nonEmpty('  hi  ')).assertEqual('hi');
    });

    it('returns undefined for whitespace-only / null / undefined', () => {
      expect(nonEmpty('   ')).assertEqual(undefined);
      expect(nonEmpty('')).assertEqual(undefined);
      expect(nonEmpty(null)).assertEqual(undefined);
      expect(nonEmpty(undefined)).assertEqual(undefined);
    });
  });

  describe('formatCostUsd', () => {
    it('renders zero as "$0.00"', () => {
      expect(formatCostUsd(0)).assertEqual('$0.00');
    });

    it('renders normal values with two decimals', () => {
      expect(formatCostUsd(1.2)).assertEqual('$1.20');
      expect(formatCostUsd(0.05)).assertEqual('$0.05');
    });

    it('renders sub-cent values as "<$0.01"', () => {
      expect(formatCostUsd(0.001)).assertEqual('<$0.01');
      expect(formatCostUsd(0.009)).assertEqual('<$0.01');
    });

    it('returns empty for null / undefined / non-finite', () => {
      expect(formatCostUsd(null)).assertEqual('');
      expect(formatCostUsd(undefined)).assertEqual('');
      expect(formatCostUsd(NaN)).assertEqual('');
      expect(formatCostUsd(Infinity)).assertEqual('');
    });
  });
}
