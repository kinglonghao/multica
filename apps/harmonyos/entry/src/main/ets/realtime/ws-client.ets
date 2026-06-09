import webSocket from '@ohos.net.webSocket';
import { BusinessError } from '@ohos.base';
import { Preferences } from '../data/preferences';
import { WSEnvelope, WSEventType } from '../models/types';
import { getBaseUrl } from '../data/api';
import { parseWSEnvelope } from '../lib/ws-validate';

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
    if (!set || set.size === 0) return;
    for (const h of set) {
      try {
        h(envelope);
      } catch (err) {
        console.warn('[ws] handler threw', err);
      }
    }
  }
}

export const wsClient: WSClient = new WSClient();
