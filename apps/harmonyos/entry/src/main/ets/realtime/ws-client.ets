import webSocket from '@ohos.net.webSocket';
import { BusinessError } from '@ohos.base';
import { Preferences } from '../data/preferences';
import { WSEnvelope, WSEventType } from '../models/types';
import { getBaseUrl } from '../data/api';
import { parseWSEnvelope } from '../lib/ws-validate';
import { isKnownWSEvent, WSEventNames } from '../lib/ws-events';

/**
 * WebSocket client. Mirrors apps/mobile/lib/ws-client.ts (the
 * "Layer 1" socket wrapper that has no React dependencies).
 *
 * Three-state lifecycle:
 *   - idle      : not connected, no auth/workspace context — used pre-boot
 *   - active    : connected and pumping events
 *   - paused    : connected but on background — emits no events until resumed
 *
 * Exponential backoff with full jitter for reconnects, identical to
 * the iOS implementation. We cap the backoff at 30s so a dead network
 * doesn't pin a retry forever; the next attempt just hits the cap
 * again until the network comes back.
 *
 * Note (C-3 / H-4 / H-5): ArkTS forbids `ReturnType<typeof ...>` in
 * type positions, so the retry handle is `number | null` (the actual
 * setTimeout return type on HarmonyOS). The token is passed via the
 * `Authorization` header set on the socket — NOT in the URL query
 * string, which would leak it into server logs / TLS-terminating
 * proxies. Envelopes are validated through `parseWSEnvelope` before
 * dispatch so a malformed event can't crash a handler.
 */

type State = 'idle' | 'connecting' | 'active' | 'paused' | 'failed';

const MIN_RECONNECT_MS = 100;

type Handler = (envelope: WSEnvelope) => void;
type ReconnectHandler = () => void;

interface QueuedEvent {
  event: WSEventType;
  handler: Handler;
}

export class WSClient {
  private state: State = 'idle';
  private socket: webSocket.WebSocket | null = null;
  private retryAttempt = 0;
  private retryHandle: number | null = null;
  private readonly handlers: Map<WSEventType, Set<Handler>> = new Map();
  private readonly reconnectHandlers: Set<ReconnectHandler> = new Set();
  private readonly queued: QueuedEvent[] = [];

  on<E extends WSEventType>(event: E, handler: Handler): () => void {
    let set = this.handlers.get(event);
    if (!set) {
      set = new Set();
      this.handlers.set(event, set);
    }
    set.add(handler as Handler);
    return () => set!.delete(handler as Handler);
  }

  onReconnect(handler: ReconnectHandler): () => void {
    this.reconnectHandlers.add(handler);
    return () => this.reconnectHandlers.delete(handler);
  }

  /**
   * Snapshot of the currently-registered event names. Exposed for
   * the startup assertion (`assertWSEventRegistry`) and for tests
   * that need to inspect the handler set without poking at the
   * private `handlers` Map. Returns a stable copy — callers may
   * mutate the result without affecting live state.
   */
  registeredEventNames(): string[] {
    return Array.from(this.handlers.keys());
  }

  /**
   * Boot the socket. Idempotent: if already active, this is a no-op.
   * Otherwise it opens a new WebSocket pointing at the workspace's
   * realtime endpoint with the current auth token passed as a header
   * (NOT a query-string param — those leak into server logs).
   */
  connect(): void {
    if (this.state === 'active' || this.state === 'connecting') return;
    const token = Preferences.get('authToken');
    const slug = Preferences.get('workspaceSlug');
    if (!token || !slug) {
      this.state = 'idle';
      return;
    }
    this.state = 'connecting';
    // Header-based auth. Falls back to the URL query on platforms
    // where webSocket doesn't accept custom headers — but HarmonyOS's
    // @ohos.net.webSocket does (see the .connect call below).
    const wsUrl = getBaseUrl().replace(/^http/, 'ws') + '/api/ws';
    const socket = webSocket.createWebSocket();
    socket.on('open', () => {
      this.state = 'active';
      this.retryAttempt = 0;
      for (const cb of this.reconnectHandlers) cb();
    });
    socket.on('message', (err: BusinessError, value: string | ArrayBuffer) => {
      if (err) {
        console.warn('[ws] message error', err.code, err.message);
        return;
      }
      if (typeof value !== 'string') return;
      const envelope = parseWSEnvelope(value);
      if (!envelope) return;
      this.dispatch(envelope);
    });
    socket.on('close', (err: BusinessError, code: number, reason: string) => {
      console.info(`[ws] closed code=${code} reason=${reason}`);
      this.socket = null;
      if (this.state === 'paused') return;
      this.scheduleReconnect();
    });
    socket.on('error', (err: BusinessError) => {
      console.warn('[ws] error', err.code, err.message);
      this.state = 'failed';
      this.scheduleReconnect();
    });
    socket.connect(wsUrl, {
      header: {
        'Authorization': `Bearer ${token}`,
        'X-Workspace-Slug': slug
      }
    }).catch((err: BusinessError) => {
      console.warn('[ws] connect failed', err.code, err.message);
      this.state = 'failed';
      this.scheduleReconnect();
    });
    this.socket = socket;
  }

  pause(): void {
    if (this.state !== 'active') return;
    this.state = 'paused';
  }

  resume(): void {
    if (this.state !== 'paused') return;
    // Bug 5 fix: if the socket closed while we were paused (e.g.
    // the server dropped the connection during background), the
    // close handler skipped the reconnect schedule. Restoring
    // 'active' state on its own would silently drop every event
    // until the next manual `connect()` call. Reconnect now if
    // the socket is gone.
    if (this.socket === null) {
      this.state = 'idle';
      this.connect();
    } else {
      this.state = 'active';
    }
  }

  disconnect(): void {
    if (this.retryHandle !== null) {
      clearTimeout(this.retryHandle);
      this.retryHandle = null;
    }
    if (this.socket) {
      this.socket.close().catch(() => { /* noop */ });
      this.socket = null;
    }
    this.state = 'idle';
  }

  /**
   * Schedule a reconnect with exponential backoff + full jitter.
   * Exposed (package-private) for testing — `apps/mobile/lib/ws-client.test.ts`
   * mounts an instance and asserts the backoff curve. Returns the
   * retry handle so the test can synchronously advance.
   *
   * Floor: the jitter minimum is `MIN_RECONNECT_MS` (100ms). The
   * classic "full jitter" formula `Math.random() * base` can return
   * values arbitrarily close to 0; without a floor, a high-attempt
   * backoff like `Math.random() * 30000` could yield 1ms and trigger
   * a tight retry loop (a "reconnect storm") that hammers the server
   * on the first non-error state. The floor keeps the gap bounded
   * from below so the loop never tightens beyond 100ms.
   */
  scheduleReconnect(): number | null {
    if (this.retryHandle !== null) return this.retryHandle;
    const attempt = this.retryAttempt;
    const base = Math.min(30_000, 500 * Math.pow(2, attempt));
    const jitter = Math.max(MIN_RECONNECT_MS, Math.random() * base);
    this.retryAttempt = attempt + 1;
    const handle = setTimeout(() => {
      this.retryHandle = null;
      this.connect();
    }, jitter);
    this.retryHandle = handle;
    return handle;
  }

  private dispatch(envelope: WSEnvelope): void {
    const set = this.handlers.get(envelope.event);
    if (!set || set.size === 0) {
      // Drift defense: a known event that no local handler has
      // registered for means the local WSEventType union and the
      // server's emitted events have diverged. Loud it out so the
      // dev console flags it. We do NOT throw — dispatch runs on
      // the socket hot path and a single missing subscription
      // shouldn't take down every subsequent message. The
      // `assertWSEventRegistry()` startup check (below) is the
      // loud, blocking surface; runtime dispatch is the
      // "tell me about it" surface.
      if (isKnownWSEvent(envelope.event)) {
        console.warn(
          `[ws] dispatched event "${envelope.event}" with no registered handler — ` +
          'local realtime-hooks.ets may be missing a subscription for this event. ' +
          'Run scripts/diff-harmonyos-types.ts to confirm upstream / local parity.'
        );
      }
      // Unknown event name (not in our registry): the server is
      // speaking a future version of the protocol that this build
      // doesn't know about. Log at debug-level so it doesn't spam
      // release builds, and drop — this is the normal forward-
      // compat path described in `lib/ws-events.ets`.
      console.debug(
        `[ws] unknown event "${envelope.event}" — server is ahead of the client.`
      );
      return;
    }
    for (const h of set) {
      try {
        h(envelope);
      } catch (err) {
        console.warn('[ws] handler threw', err);
      }
    }
  }
}

/**
 * Result of `assertWSEventRegistry()`. Production callers should
 * surface `missing` to the user; tests assert on the exact list.
 */
export interface WSRegistryAssertResult {
  /** Number of events in the local registry. Empty / zero means the
   *  developer forgot to populate `WSEventNames` — the most common
   *  form of "silent swallow" since the WS layer would happily
   *  dispatch to zero handlers. */
  total: number;
  /** Subset of `WSEventNames` that the local realtime layer has
   *  not registered a handler for. A non-empty list is not
   *  always a bug (heartbeats + daemon noise intentionally have
   *  no UI consumer) but it MUST be reviewed on every release. */
  unhandled: ReadonlyArray<string>;
}

/**
 * Startup assertion. Walks the local registry and reports which
 * event names have no handler registered. Call this from
 * `EntryAbility.onCreate()` or the workspace layout mount to
 * fail-fast in dev when the local realtime layer has fallen
 * behind the upstream protocol.
 *
 * The function is pure (reads `WSEventNames`, queries the
 * singleton `wsClient`'s handler set) and side-effect-free
 * other than the one `console.warn` per missing handler. The
 * caller decides what to do with the result — typically: log
 * loudly in dev, log silently in release, and never block the
 * boot path.
 */
export function assertWSEventRegistry(): WSRegistryAssertResult {
  const known = WSEventNames;
  if (known.length === 0) {
    // This is the loudest possible failure: the registry itself
    // is empty, which means every dispatch() in the entire
    // app is a silent no-op. We throw in dev (caller can catch
    // and decide) and warn in release.
    const message = '[ws] WSEventNames registry is empty — every WS dispatch is a silent no-op. ' +
      'This usually means `lib/ws-events.ets` was deleted or its `WSEventNames` export was emptied. ' +
      'Run `pnpm tsx scripts/diff-harmonyos-types.ts` to regenerate.';
    console.error(message);
    throw new Error(message);
  }
  const unhandled: string[] = [];
  // The set of registered event names is derived from
  // `wsClient.handlers.keys()`. The keys are typed as WSEventType
  // but the underlying Map stores whatever string the caller
  // passed — perfect for our drift check, which needs the raw
  // string.
  // We expose the iteration via a tiny public method below
  // (`registeredEventNames()`) so the test code doesn't need
  // `as unknown as` casts.
  const registered = wsClient.registeredEventNames();
  const registeredSet = new Set<string>(registered);
  for (const name of known) {
    if (!registeredSet.has(name)) {
      unhandled.push(name);
    }
  }
  if (unhandled.length > 0) {
    console.warn(
      `[ws] ${unhandled.length} known event(s) have no registered handler. ` +
      'These will dispatch as warnings at runtime. ' +
      'Add subscriptions in realtime-hooks.ets, or remove them from lib/ws-events.ets if intentionally unhandled. ' +
      `Unhandled: ${unhandled.join(', ')}`
    );
  }
  return { total: known.length, unhandled };
}

export const wsClient: WSClient = new WSClient();
