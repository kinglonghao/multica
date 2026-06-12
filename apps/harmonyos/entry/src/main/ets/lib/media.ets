/**
 * Media helpers — central place for resolving server-side media
 * URLs and choosing local fallback assets.
 *
 * On HarmonyOS, `Image(src)` accepts three forms:
 *   - a `Resource` reference (`$r('app.media.foo')`) for assets
 *     bundled in `entry/src/main/resources/`
 *   - a `string` URL for network / file URIs
 *   - a `PixelMap` for in-memory bitmaps
 *
 * The iOS client (apps/mobile/lib/attachment-url.ts) has a
 * `resolveAttachmentUrl` helper that strips spaces and
 * normalizes the path. HarmonyOS doesn't have a direct
 * equivalent — `Image` resolves URLs natively — but it does
 * have a quirk: the server returns *signed* URLs that expire,
 * and the Image cache may outlive the signature. We expose
 * `attachmentUrl` so call sites have one place to add a cache
 * buster later if signatures expire faster than expected.
 *
 * Adding a new asset:
 *   1. Drop the file under
 *      `entry/src/main/resources/base/media/<name>.<ext>`.
 *   2. Reference it as `$r('app.media.<name>')` in the page.
 *   3. If the asset has a light + dark variant, also drop the
 *      dark variant under
 *      `entry/src/main/resources/dark/media/<name>.<ext>` and
 *      use the SAME name; ArkUI will pick the right one
 *      automatically based on system color mode.
 *
 * Why this helper exists even when most pages use $r() inline:
 *   - Test seam — a future Vitest-style suite can swap the
 *     `assetFor()` mapper and assert that pages render the
 *     expected asset key.
 *   - One place to document the "media" resource convention
 *     (see CLAUDE.md "Apps that grow beyond M4").
 */

export type AssetName =
  | 'icon_launcher'
  | 'icon_chat_placeholder'
  | 'icon_issue_placeholder'
  | 'icon_avatar_fallback';

const ASSET_TABLE: Record<AssetName, string> = {
  icon_launcher: 'app.media.icon_launcher',
  icon_chat_placeholder: 'app.media.icon_chat_placeholder',
  icon_issue_placeholder: 'app.media.icon_issue_placeholder',
  icon_avatar_fallback: 'app.media.icon_avatar_fallback'
};

/**
 * Resolve a logical asset name to the resource key the rest of
 * the app consumes. Page code calls `assetFor('icon_launcher')`
 * and the helper returns a string the JSX can plug into Image.
 */
export const assetFor: (name: AssetName) => string =
  (name: AssetName): string => ASSET_TABLE[name];

/**
 * Normalize a server-returned media URL. Currently a no-op
 * (kept for parity with apps/mobile/lib/attachment-url.ts) but
 * a future change can add:
 *   - signed-URL cache busting
 *   - path rewriting to a CDN host
 *   - null/undefined fallbacks
 *
 * Call sites that currently use a raw URL inline should
 * migrate to `attachmentUrl()` so a single edit here covers
 * all attachments.
 */
export const attachmentUrl: (url: string | null | undefined) => string =
  (url: string | null | undefined): string => {
    if (!url) return '';
    return url;
  };
