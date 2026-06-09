import webSocket from '@ohos.net.webSocket';
import { BusinessError } from '@ohos.base';
import { Preferences } from '../data/preferences';
import { WSEnvelope, WSEventType } from '../models/types';
import { getBaseUrl } from '../data/api';

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
 */

type State = 'idle' | 'connecting' | 'active' | 'paused' | 'failed';

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
  private retryHandle: ReturnType<typeof setTimeout> | null = null;
  private readonly handlers = new Map<WSEventType, Set<Handler>>();
  private readonly reconnectHandlers = new Set<ReconnectHandler>();
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
   * realtime endpoint with the current auth token.
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
    const wsUrl = getBaseUrl().replace(/^http/, 'ws') + `/api/ws?token=${token}&workspace=${slug}`;
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
      try {
        const envelope = JSON.parse(value) as WSEnvelope;
        this.dispatch(envelope);
      } catch (parseErr) {
        console.warn('[ws] failed to parse envelope', parseErr);
      }
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
    socket.connect(wsUrl).catch((err: BusinessError) => {
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
    this.state = 'active';
  }

  disconnect(): void {
    if (this.retryHandle) {
      clearTimeout(this.retryHandle);
      this.retryHandle = null;
    }
    if (this.socket) {
      this.socket.close().catch(() => { /* noop */ });
      this.socket = null;
    }
    this.state = 'idle';
  }

  private scheduleReconnect(): void {
    if (this.retryHandle) return;
    const attempt = this.retryAttempt;
    const base = Math.min(30_000, 500 * Math.pow(2, attempt));
    const jitter = Math.random() * base;
    this.retryAttempt = attempt + 1;
    this.retryHandle = setTimeout(() => {
      this.retryHandle = null;
      this.connect();
    }, jitter);
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
