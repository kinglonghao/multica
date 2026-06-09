/**
 * Time-ago formatter. Mirrors apps/mobile/lib/time-ago.ts.
 *
 * Renders a relative timestamp like "5m ago" / "3h ago" / "2d ago".
 * Server timestamps are RFC3339 strings (typically with 'Z' suffix).
 * If the timestamp can't be parsed we fall back to the raw input rather
 * than rendering the literal "Invalid Date" — that would be a 2025-era
 * regression we already paid for in the iOS client.
 *
 * Note (C-8): ArkTS disallows module-level `function` declarations
 * that capture external state — they have to be `const` arrow
 * functions instead. `futureIn` is private to this module and only
 * used by `timeAgo`, so an arrow const inside the same file is
 * the idiomatic shape.
 */

export const timeAgo: (input: string | Date | number | null | undefined) => string =
  (input: string | Date | number | null | undefined): string => {
    if (input === null || input === undefined) return '';
    const d = typeof input === 'string' || typeof input === 'number' ? new Date(input) : input;
    if (isNaN(d.getTime())) return typeof input === 'string' ? input : '';
    const diff = Date.now() - d.getTime();
    if (diff < 0) {
      return futureIn(Math.abs(diff));
    }
    const seconds = Math.floor(diff / 1000);
    if (seconds < 45) return 'just now';
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m ago`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h ago`;
    const days = Math.floor(hours / 24);
    if (days < 30) return `${days}d ago`;
    const months = Math.floor(days / 30);
    if (months < 12) return `${months}mo ago`;
    const years = Math.floor(days / 365);
    return `${years}y ago`;
  };

const futureIn: (ms: number) => string = (ms: number): string => {
  const seconds = Math.floor(ms / 1000);
  if (seconds < 60) return 'in a moment';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `in ${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `in ${hours}h`;
  const days = Math.floor(hours / 24);
  if (days < 30) return `in ${days}d`;
  const months = Math.floor(days / 30);
  if (months < 12) return `in ${months}mo`;
  return `in ${Math.floor(days / 365)}y`;
};

/**
 * Class-merge helper. Mirrors apps/mobile/lib/utils.ts `cn()`. ArkUI
 * doesn't use string class names the way web does, but we keep the
 * helper for parity — downstream code can paste in the same
 * conditional-class string and `cn` will trim whitespace and
 * deduplicate separators.
 */
export const cn: (...parts: Array<string | false | null | undefined>) => string =
  (...parts: Array<string | false | null | undefined>): string => {
    return parts.filter(p => typeof p === 'string' && p.length > 0).join(' ').trim();
  };
