/**
 * Time-ago formatter. Mirrors apps/mobile/lib/time-ago.ts.
 *
 * Renders a relative timestamp like "5m ago" / "3h ago" / "2d ago".
 * Server timestamps are RFC3339 strings (typically with 'Z' suffix).
 * If the timestamp can't be parsed we fall back to the raw input rather
 * than rendering the literal "Invalid Date" — that would be a 2025-era
 * regression we already paid for in the iOS client.
 */
export function timeAgo(input: string | Date | number | null | undefined): string {
  if (input === null || input === undefined) return '';
  const d = typeof input === 'string' || typeof input === 'number' ? new Date(input) : input;
  if (isNaN(d.getTime())) return typeof input === 'string' ? input : '';
  const diff = Date.now() - d.getTime();
  if (diff < 0) {
    // Future timestamp (clock skew, scheduled-for-later). Round to the
    // largest unit the gap covers. iOS does the same to avoid "−5m ago".
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
}

function futureIn(ms: number): string {
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
}

/**
 * Class-merge helper. Mirrors apps/mobile/lib/utils.ts `cn()`. ArkUI
 * doesn't use string class names the way web does, but we keep the
 * helper for parity — downstream code can paste in the same
 * conditional-class string and `cn` will trim whitespace and
 * deduplicate separators.
 */
export function cn(...parts: Array<string | false | null | undefined>): string {
  return parts.filter(p => typeof p === 'string' && p.length > 0).join(' ').trim();
}
