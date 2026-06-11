# HarmonyOS App Rules (apps/harmonyos/)

## What the HarmonyOS app may import from elsewhere

**Nothing at runtime.** This is the strictest sharing rule in the
workspace — even stricter than the iOS mobile app:

- The web + desktop share zone stops at `apps/mobile/`. The
  HarmonyOS app sits further outside.
- The iOS mobile app imports `import type` from
  `@multica/core/types/*` (zero runtime coupling). The HarmonyOS
  build does not have access to that package — its compiler is the
  standalone ArkTS toolchain, not the workspace's pnpm/turbo
  pipeline — so types are mirrored into
  `entry/src/main/ets/models/types.ets` as a maintenance
  responsibility, not a build-time dependency.
- No `import` from `apps/mobile/`, `apps/web/`, `apps/desktop/`, or
  any of the `packages/*` directories.

## Mirror-don't-import: when updating types

`models/types.ets` is a hand-mirror of `packages/core/types/`. The
header comment in that file spells out the rules — they exist to
prevent silent drift:

1. **Add a new field** in `models/types.ets` the same day the field
   lands in `packages/core/types/<domain>.ts`.
2. **Never invent a field** that's not in upstream. The server
   contract is the source of truth and a phantom field will
   silently fall through `parseWithFallback` as `undefined`.
3. **When in doubt**, fetch the latest
   `packages/core/types/<domain>.ts` from main and diff line by
   line.

When `packages/core/types/events.ts` adds a new `WSEventType`, the
new event name MUST also be added to the `WSEventType` union in
`models/types.ets` — otherwise the WS client silently swallows it
because `this.handlers.get(event)` returns undefined for an
unknown name.

**After every rebase / merge of `main`**, run the drift gate:

```bash
node scripts/diff-harmonyos-types.mjs
```

The script compares three sources of truth — upstream
`packages/core/types/events.ts::WSEventType`, the mirrored union
in `models/types.ets::WSEventType`, and the runtime registry in
`lib/ws-events.ets::WSEventNames` — and exits non-zero on drift.
It is also wired into `.github/workflows/harmonyos-smoke.yml`
(J1) so the same check runs on every PR that touches the
harmonyos app or any core type. A green exit (`exit 0`) means
all three are in lockstep; a red exit (`exit 1`) means at least
one of them is behind `main`.

**Why a separate runtime registry when the union already lists
every event?** The TypeScript union is erased at runtime — a new
event name added upstream compiles cleanly here, then is silently
dropped at runtime by `wsClient.dispatch()` because
`handlers.get(newEvent)` returns undefined. The registry gives us
a Set to test membership against in `ws-client.ets::dispatch()`,
so the silent skip becomes a logged warning at minimum. The
startup-time `assertWSEventRegistry()` (also in `ws-client.ets`)
walks the registry at boot and reports any event that has zero
subscribers — call it from `EntryAbility` if you want a fail-fast
on every cold start.

## Behavioral parity

The HarmonyOS app is allowed to differ in **UI and interaction**
(HarmonyOS has its own navigation patterns, gestures, and
component library). It is NOT allowed to differ in **product
semantics** — counts, enums, permissions, and data identity must
match the iOS app.

The four parity points from `apps/mobile/CLAUDE.md` apply
verbatim:

- **Counts / visibility** — same N for the same filter, under
  identical pagination / coalescing rules. The inbox dedup helper
  (`lib/inbox-display.ets`) is a direct port of
  `apps/mobile/lib/inbox-display.ts` — do not skip it when
  rendering the inbox tab.
- **Permissions / access** — mirror web, not invent. The auth
  store uses the same 401 → clear → navigate flow.
- **State enums / transitions** — render every status / priority
  / inbox type / comment type, with a sensible fallback for
  unknown values. The status / priority labels in
  `lib/issue-status.ets` and `lib/project-status.ets` already
  include a `?? status` / `?? priority` fallback; do not delete
  it.
- **Data identity** — same `id`, same `slug`, same canonical
  fields. Don't invent ids or normalize differently.

## Tech-stack baseline

- **ArkTS** strict mode (TypeScript superset with stricter type
  rules).
- **HarmonyOS 5.0** (API 12) minimum compatible SDK.
- **Stage model** with a single UIAbility (EntryAbility).
- **ArkUI** declarative UI framework.
- `@ohos.net.http` for HTTP, `@ohos.net.webSocket` for WS,
  `@ohos.data.preferences` for secure KV storage.

When upgrading any of these, update the README and this list.

## UI component placement

- **Generic UI primitives** → `components/ui/`. Mirrors
  `apps/mobile/components/ui/` 1:1 (Text, Button, Header,
  IconButton, Card, Avatar, Skeleton, Separator, StatusIcon,
  PriorityIcon, ProjectStatusIcon).
- **Domain UI** → `components/<domain>/`. Currently:
  `inbox/InboxRow`, `issue/IssueRow`, `project/ProjectRow`. Add
  new ones here, not in `ui/`.
- **Pages** → `pages/<PageName>.ets` with `@Entry` and a single
  top-level struct. Mirrors `apps/mobile/app/(app)/[workspace]/`.

## Theming

CSS variables don't exist on ArkUI; we use a plain TS object
(`lib/theme.ets`) keyed by the current `ColorScheme`. The whole
app is intended to be wrapped in a theme controller that
re-renders on `light` / `dark` / `system` change; v0.1 hardcodes
`'light'` (see `detectScheme()` stubs in each page) and the
switcher is a follow-up.

When you change a color in `lib/theme.ets`, change BOTH the
`light` and `dark` entries — there's no tokens.css diff to catch
a missed variant.

## Realtime

`realtime/ws-client.ets` mirrors `apps/mobile/lib/ws-client.ts`
verbatim. Three-state lifecycle, exponential backoff with full
jitter, idempotent `connect()`. Mount it from `WorkspaceLayout`
(unmount on sign-out).

When adding event coverage, mirror
`apps/mobile/data/realtime/<feature>-ws-updaters.ts` — do NOT
import the iOS file. The two clients speak the same protocol but
hold their own cache keys (3-segment shape, derived from
`workspaceStore.currentId`), so the iOS updaters will silently
no-op against the HarmonyOS cache.

## Lessons (encode into reflexes)

These are the gotchas that would burn a future agent:

1. **Imports at the top of the file** — ArkTS does not allow
   `import` statements after the first non-import declaration. The
   first cut of `WorkspaceLayout.ets` had its tab-page imports at
   the bottom of the file; this fails to compile. Always put
   `import` statements at the top.
2. **`forEach` with a static array** — `ForEach([1, 2, 3], …)` is
   fine for skeleton loaders. For dynamic lists, pass the array
   directly: `ForEach(items, …)`.
3. **`@ohos.net.http` does not pool connections** — each request
   builds a new `httpRequest` and destroys it eagerly. Don't
   cache the request object between calls.
4. **The `EntryAbility` boot path is blocking** — `loadContent`
   happens inside `onWindowStageCreate`. We await
   `PreferencesBootstrap.init()` before `loadContent` so the
   first frame reads auth state synchronously. Do not move the
   bootstrap into a parallel task — that produces a "flash of
   logged-out" frame on cold launch.
5. **The `authStore` 401 callback is wired in two places** —
   once in `verifyOtp` and once at the bottom of `auth.ets`. The
   `setOptions` call merges, so calling it twice is safe, but
   the second call MUST happen for the unauthed boot path
   (otherwise an expired session on first GET would log without
   the forced-redirect).
6. **`parseWithFallback` is a future port** — the iOS ApiClient
   has it; the HarmonyOS version is `JSON.parse` until
   zod-equivalent is on the platform. When a field comes back
   with the wrong shape, the read path will throw rather than
   returning a fallback. Frontend code should `?.` / default
   every field as a defensive measure.
