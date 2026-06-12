/**
 * Pure-function utility library. Mirrors the small helper modules
 * in `apps/mobile/lib/` (format-elapsed, format-activity,
 * failure-reason-label, request-id, inline-color, etc.) — every
 * export here is a `const` arrow function (ArkTS strict mode
 * disallows module-level `function` declarations that capture
 * external state).
 *
 * Why a separate file from `utils.ets`:
 *   - `utils.ets` ships the universal "time-ago / cn" helpers
 *     and is required at boot by every page.
 *   - `format-utils.ets` is the read-path-specific surface:
 *     formatters for the agent task / run list, activity
 *     timeline, and project resource rows. Pages opt in by
 *     importing the specific export they need.
 *
 * Two rules for adding to this file:
 *   1. If the helper depends on a query / API call, it does NOT
 *      belong here. This file is for pure functions only.
 *   2. If the helper is page-specific (e.g. only used by the
 *      issue-detail timeline), prefer inlining it in the page
 *      file. This file is for cross-page primitives.
 */

/**
 * Format an elapsed duration in seconds. Mirrors
 * `apps/mobile/lib/format-elapsed.ts` — same `Xs` / `Xm Ys` /
 * `Xm` buckets used by the iOS "Thinking · 38s" pill and the
 * "Replied in 39s" caption.
 *
 * Negative inputs clamp to 0 (we never want "-3s" in the UI).
 * `Infinity` / `NaN` clamp to "0s" so a broken server field
 * renders something safe.
 */
export const formatElapsedSecs: (secs: number) => string =
  (secs: number): string => {
    if (!isFinite(secs) || isNaN(secs) || secs < 0) return '0s';
    const s = Math.floor(secs);
    if (s < 60) return `${s}s`;
    const m = Math.floor(s / 60);
    const r = s % 60;
    return r ? `${m}m ${r}s` : `${m}m`;
  };

/** Same formatter, but the input is milliseconds (server stores
 *  `elapsed_ms` and `duration_ms` as integers). */
export const formatElapsedMs: (ms: number) => string =
  (ms: number): string => {
    return formatElapsedSecs(Math.max(0, Math.round(ms / 1000)));
  };

/**
 * Short, timezone-safe date-only formatter. Returns
 * "Jun 12" / "Jun 12, 2024" / "?" for missing / unparseable
 * input. We deliberately do NOT use `toLocaleDateString` with a
 * timezone — the server stores calendar dates (start_date,
 * due_date) as YYYY-MM-DD without a time component, and feeding
 * those through a local-timezone formatter shifts the day on
 * UTC-negative offsets. We split on the `-` and rebuild with
 * a static English month name so the result is stable across
 * devices and locales.
 */
const MONTH_NAMES: ReadonlyArray<string> = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

export const shortDate: (date: string | null | undefined) => string =
  (date: string | null | undefined): string => {
    if (!date) return '?';
    // Accept "YYYY-MM-DD" and "YYYY-MM-DDTHH:MM:SS[Z|+00:00]".
    const datePart = date.length >= 10 ? date.substring(0, 10) : date;
    const parts = datePart.split('-');
    if (parts.length !== 3) return date;
    const y = Number(parts[0]);
    const m = Number(parts[1]);
    const d = Number(parts[2]);
    if (!isFinite(y) || !isFinite(m) || !isFinite(d)) return date;
    if (m < 1 || m > 12) return date;
    const monthName = MONTH_NAMES[m - 1];
    const now = new Date();
    const sameYear = now.getFullYear() === y;
    return sameYear ? `${monthName} ${d}` : `${monthName} ${d}, ${y}`;
  };

/** Failure reason label for agent tasks. Mirrors
 *  `apps/mobile/lib/failure-reason-label.ts`. Unknown values
 *  fall through to a generic "Failed" — the iOS client does the
 *  same so a new server-side enum value doesn't crash the row. */
export const failureReasonLabel: (reason: string | null | undefined) => string =
  (reason: string | null | undefined): string => {
    if (!reason) return 'Failed';
    switch (reason) {
      case 'timeout': return 'Timed out';
      case 'auth': return 'Authentication failed';
      case 'rate_limit': return 'Rate limited';
      case 'crash': return 'Crashed';
      case 'user_abort': return 'Cancelled by user';
      case 'unknown': return 'Failed';
      default: return 'Failed';
    }
  };

/** Truncate a string to a max length, appending an ellipsis if
 *  truncation happened. Used by the runs tab description preview
 *  and the activity timeline. Empty / nullish input returns the
 *  same empty shape (no ellipsis) so consumers can render
 *  "no description" consistently. */
export const truncate: (s: string | null | undefined, max: number) => string =
  (s: string | null | undefined, max: number): string => {
    if (!s) return '';
    if (s.length <= max) return s;
    if (max <= 1) return s.substring(0, max);
    return s.substring(0, max - 1) + '…';
  };

/** Stable serializer for plain-object map keys. Avoids
 *  `JSON.stringify`'s key-order non-determinism across engines
 *  (the same warning we have in `queries/issue.ets::stableKeyOfParams`).
 *  Sorts the keys alphabetically and concatenates `k=v` pairs. */
export const stableKeyForObject: (obj: Record<string, unknown> | null | undefined) => string =
  (obj: Record<string, unknown> | null | undefined): string => {
    if (!obj) return '';
    const keys = Object.keys(obj).sort();
    const parts: string[] = [];
    for (const k of keys) {
      const v = obj[k];
      if (v === null || v === undefined) continue;
      if (Array.isArray(v)) {
        if (v.length === 0) continue;
        parts.push(`${k}=${v.map((x) => String(x)).sort().join(',')}`);
      } else {
        parts.push(`${k}=${String(v)}`);
      }
    }
    return parts.join('&');
  };

/** Pick the first defined value from a list. Lets callers write
 *  `firstDefined(env.payload.id, env.payload.issue?.id, '')`
 *  without the nested-ternary soup. */
export const firstDefined: <T>(...args: Array<T | null | undefined>) => T | undefined =
  <T>(...args: Array<T | null | undefined>): T | undefined => {
    for (const a of args) {
      if (a !== null && a !== undefined) return a;
    }
    return undefined;
  };

/** Pluck a non-empty string. Treats whitespace-only as empty
 *  (a server-stored " " is just an absent field for display
 *  purposes). Returns undefined for null / undefined / ''. */
export const nonEmpty: (s: string | null | undefined) => string | undefined =
  (s: string | null | undefined): string | undefined => {
    if (s === null || s === undefined) return undefined;
    const trimmed = s.trim();
    return trimmed.length > 0 ? trimmed : undefined;
  };

/** Format a cost value (USD) as "$1.23" / "$0.05" / "<$0.01".
 *  Mirrors the iOS cost display in the runs tab. The threshold
 *  matches what the web view uses for "<$0.01" fallbacks. */
export const formatCostUsd: (n: number | null | undefined) => string =
  (n: number | null | undefined): string => {
    if (n === null || n === undefined || !isFinite(n)) return '';
    if (n === 0) return '$0.00';
    if (n > 0 && n < 0.01) return '<$0.01';
    return `$${n.toFixed(2)}`;
  };
