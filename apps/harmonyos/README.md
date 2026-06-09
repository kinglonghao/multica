# Multica HarmonyOS Mobile Client

The HarmonyOS port of the Multica mobile client. Mirrors the iOS app
(`apps/mobile/`) feature-for-feature: OTP auth, workspace switcher, tabs
for Inbox / My Issues / Chat / More, full issue and project detail,
new-issue flow, search, profile, notifications, and the realtime
WebSocket layer that keeps the inbox in sync.

This is a **new app**, not a fork of `apps/mobile/`. The two share only
type shapes (the data model in `entry/src/main/ets/models/types.ets`
is a hand-mirror of `packages/core/types/` — see the file's header for
the maintenance rules). The runtime, build pipeline, and UI toolkit
are independent: ArkTS + ArkUI on HarmonyOS, React Native + Expo on iOS.

## Project layout

```
apps/harmonyos/
├── AppScope/                    # App-wide config (bundleName, vendor, version)
├── entry/                       # Main HAP module
│   ├── build-profile.json5      # Module build config
│   ├── hvigorfile.ts            # Module build script
│   ├── obfuscation-rules.txt    # Release build obfuscation hooks
│   └── src/main/
│       ├── module.json5         # Module manifest (abilities, permissions)
│       ├── ets/                 # ArkTS source
│       │   ├── entryability/    # EntryAbility.ets (boot lifecycle)
│       │   ├── entrybackupability/
│       │   ├── pages/           # Top-level routed pages
│       │   ├── components/      # UI components by domain
│       │   │   ├── ui/          # Primitives (Text, Button, Header, Avatar…)
│       │   │   ├── inbox/       # InboxRow
│       │   │   ├── issue/       # IssueRow
│       │   │   ├── project/     # ProjectRow
│       │   │   ├── chat/
│       │   │   ├── nav/
│       │   │   ├── workspace/
│       │   │   ├── brand/
│       │   │   ├── composer/
│       │   │   └── editor/
│       │   ├── data/            # ApiClient, stores, preferences
│       │   ├── lib/             # Pure helpers (theme, status, time-ago…)
│       │   ├── models/          # Type definitions (mirrored from packages/core)
│       │   ├── queries/         # Read-side cache + per-feature query hooks
│       │   ├── mutations/       # Write-side optimistic mutations
│       │   └── realtime/        # WebSocket client
│       └── resources/           # String/color/profile resources
├── build-profile.json5          # App-level build config
├── code-linter.json5            # ESLint-style rules
├── hvigorfile.ts                # Workspace build entry
└── oh-package.json5             # Workspace manifest
```

## Building

This project uses the HarmonyOS hvigor build system. Build it with
DevEco Studio (HUAWEI's IDE) or via the CLI:

```bash
# From apps/harmonyos
hvigorw clean
hvigorw assembleHap --mode module -p product=default
```

The build outputs a `.hap` (HarmonyOS Ability Package) under
`entry/build/default/outputs/default/entry-default-signed.hap`. Install
on a device or emulator with HDC:

```bash
hdc install entry/build/default/outputs/default/entry-default-signed.hap
hdc shell aa start -b ai.multica.harmonyos
```

## Configuration

The app reads `EXPO_PUBLIC_API_URL`-equivalent values from a small
config at boot. Defaults to `https://api.multica.ai`; override by
calling `setBaseUrl('https://your-server')` early in `EntryAbility.ets`.

## Behavioral parity with the iOS client

This app is allowed to differ in **interaction** (HarmonyOS has its own
gestures, navigation patterns, and tab-bar conventions). It is **not**
allowed to differ in **product semantics**. The mirroring rules from
`apps/mobile/CLAUDE.md` apply verbatim:

- Inbox dedup, unread counts, status / priority enums, identifiers —
  identical to the iOS app.
- Cache shapes mirror `data/queries/<feature>.ts` (3-segment keys, same
  string set, no exotic variants). Mirror, don't import — the iOS
  `import type` whitelist from `@multica/core/types` doesn't apply on
  HarmonyOS, so the types are inlined into
  `entry/src/main/ets/models/types.ets`. When in doubt, fetch the
  latest `packages/core/types/<domain>.ts` and diff line by line.
- Realtime: same `WSEventType` union, same `WSEnvelope` shape. The
  WSClient (entry/src/main/ets/realtime/ws-client.ts) uses the same
  three-state lifecycle (idle / active / paused) and the same
  exponential-backoff-with-jitter reconnect loop.

## Known gaps vs the iOS client (v0.1)

- File uploads (`uploadFile` in `data/api.ets`) throw 501 — the
  `@ohos.net.http` FormData flow differs from web fetch and needs
  a follow-up to wire up correctly.
- Theme switcher is a stub — the `light` / `dark` / `system` picker
  lives in the iOS Profile screen; HarmonyOS uses the system theme
  for v0.1.
- Markdown rendering for issue descriptions / comments is plain text
  (no Shiki highlighter, no enriched markdown) — iOS uses
  `react-native-enriched-markdown`. The hook in `lib/markdown/` is
  reserved for a future port.
- Picker sheets (status / priority / assignee / project pickers in
  iOS) are inline row pickers in v0.1. The full formSheet picker
  experience from iOS (modal `presentation: "formSheet"` with
  detents and grabber) is a follow-up.

## Module dependencies (apps/mobile/CLAUDE.md mirror)

- The mobile client is **independent**. The web / desktop share zone
  stops at `apps/mobile/`. The HarmonyOS app sits further outside —
  it does not import from `apps/mobile/` or `apps/web/` or
  `apps/desktop/` or any of the shared `packages/`. The type mirror
  in `models/types.ets` is a maintenance responsibility, not a
  build-time dependency.
