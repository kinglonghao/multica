/**
 * WebSocket event registry — runtime mirror of
 * `packages/core/types/events.ts::WSEventType`.
 *
 * Why this file exists:
 *
 * The HarmonyOS build does NOT import from `packages/core/types/*` (see
 * apps/harmonyos/CLAUDE.md "What the HarmonyOS app may import from
 * elsewhere"). The TypeScript union in `models/types.ets::WSEventType`
 * is the only thing the rest of the app can see at compile time, but
 * unions are erased at runtime — a new event name added upstream would
 * compile cleanly here, then be silently dropped at runtime by
 * `wsClient.dispatch()` because `handlers.get(newEvent)` returns
 * `undefined` for an unrecognised name. That silent-skip is the
 * M1-stability risk the project is paying down.
 *
 * This file pins the *known* event names as a runtime array. It must
 * stay in lockstep with `packages/core/types/events.ts::WSEventType`:
 *
 *   1. `scripts/diff-harmonyos-types.ts` (J3) runs in CI and on every
 *      rebase of `main` to detect drift between the upstream union
 *      and the array below.
 *   2. `ws-client.ets::assertWSEventRegistry()` (E1) checks the
 *      handler set at boot time and fails fast if upstream emits a
 *      name that no local handler has registered for, so the silent
 *      skip becomes a loud, in-app error in dev and a one-line
 *      warning in release.
 *
 * Adding a new event:
 *   - Add the string to `WSEventNames` below (in the same order as
 *     upstream's `WSEventType` union for easy diff).
 *   - If you need the payload shape, add it to `WSEventPayloadMap`
 *     in `models/types.ets`.
 *   - Run `pnpm tsx scripts/diff-harmonyos-types.ts` locally to
 *     confirm zero drift before opening a PR.
 *
 * Removing an event: same drill in reverse — drop the name here,
 * drop the `WSEventType` union member in `models/types.ets`, drop
 * the payload map entry. The diff script will fail if any of the
 * three goes out of sync.
 *
 * The `| string` on the WSEventType union in `models/types.ets`
 * means an upstream event we haven't mirrored yet is still accepted
 * at runtime by the validator — this is intentional. The point of
 * the registry is to *detect* that gap loudly, not to *prevent*
 * it. The protocol is the source of truth, and the local app must
 * accept whatever upstream sends (otherwise a server deployment
 * would instantly brick every HarmonyOS client in the field).
 */

export const WSEventNames: ReadonlyArray<string> = [
  // Issues
  'issue:created',
  'issue:updated',
  'issue:deleted',
  // Comments
  'comment:created',
  'comment:updated',
  'comment:deleted',
  'comment:resolved',
  'comment:unresolved',
  // Agents
  'agent:status',
  'agent:created',
  'agent:archived',
  'agent:restored',
  // Tasks
  'task:queued',
  'task:dispatch',
  'task:running',
  'task:waiting_local_directory',
  'task:progress',
  'task:completed',
  'task:failed',
  'task:message',
  'task:cancelled',
  // Inbox
  'inbox:new',
  'inbox:read',
  'inbox:archived',
  'inbox:batch-read',
  'inbox:batch-archived',
  // Workspace / Members
  'workspace:updated',
  'workspace:deleted',
  'member:added',
  'member:updated',
  'member:removed',
  // Daemon (system noise — no UI consumer; included for completeness)
  'daemon:heartbeat',
  'daemon:register',
  // Skills
  'skill:created',
  'skill:updated',
  'skill:deleted',
  // Subscribers
  'subscriber:added',
  'subscriber:removed',
  // Activity / reactions
  'activity:created',
  'reaction:added',
  'reaction:removed',
  'issue_reaction:added',
  'issue_reaction:removed',
  // Chat
  'chat:message',
  'chat:done',
  'chat:session_read',
  'chat:session_deleted',
  'chat:session_updated',
  // Projects
  'project:created',
  'project:updated',
  'project:deleted',
  // Squads
  'squad:created',
  'squad:updated',
  'squad:deleted',
  // Labels
  'label:created',
  'label:updated',
  'label:deleted',
  // Issue-side annotations
  'issue_labels:changed',
  'issue_metadata:changed',
  // Pins
  'pin:created',
  'pin:deleted',
  'pin:reordered',
  // Invitations
  'invitation:created',
  'invitation:accepted',
  'invitation:declined',
  'invitation:revoked',
  // GitHub installations / PRs
  'github_installation:created',
  'github_installation:deleted',
  'pull_request:linked',
  'pull_request:updated',
  'pull_request:unlinked'
];

/**
 * O(1) membership test. Used by the WS validator to short-circuit
 * the slow `Set.has` lookup on the hot path. Built lazily on first
 * access so the cold-start cost is paid only when the registry is
 * actually consulted.
 */
let cachedSet: Set<string> | null = null;

export function isKnownWSEvent(name: string): boolean {
  if (cachedSet === null) {
    cachedSet = new Set<string>(WSEventNames);
  }
  return cachedSet.has(name);
}

/**
 * Reset the lazy cache. Tests call this between cases so a fresh
 * `isKnownWSEvent` lookup rebuilds from the (possibly mutated)
 * `WSEventNames` array. Production never needs to call it.
 */
export function resetWSEventCache(): void {
  cachedSet = null;
}
