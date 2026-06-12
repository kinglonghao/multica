/**
 * Realtime lifecycle manager — foreground/background, network
 * recovery, and a single source of truth for the WS connect call.
 *
 * The HarmonyOS build has THREE different ways the WS connection
 * can drop silently:
 *   1. The user backgrounds the app — the OS may suspend the
 *      WebSocket, but we don't want the user's session to look
 *      "offline" while they're reading a notification. We
 *      `pause()` (mark the client as paused, drop incoming
 *      events) so we don't churn the cache with stale data, and
 *      `resume()` reconnects if the socket closed while we were
 *      paused.
 *   2. The device loses the network — `@ohos.net.connection` is
 *      the canonical way to observe link-state changes on
 *      HarmonyOS. We forward `lost` → pause, `available` →
 *      resume. Without this hook a phone that comes back from a
 *      tunnel will leave the WS in the `failed` state until the
 *      user manually reloads.
 *   3. The server restarts — the WS client's backoff (see
 *      `ws-client.ets::scheduleReconnect`) handles this, but the
 *      `onReconnect` callback in the client gives us a hook to
 *      fire cache invalidations so any events we missed while
 *      disconnected are reconciled.
 *
 * `RealtimeLifecycle` is a singleton mounted from EntryAbility.
 * It owns the network subscription, the lifecycle observer, and
 * the WS connect/disconnect orchestration. Pages don't call it
 * directly — they call `realtime-hooks.ets` from `aboutToAppear`
 * and rely on this module to keep the socket alive in the
 * background.
 *
 * The class is intentionally minimal: it's a coordinator, not a
 * cache, and it doesn't replay events. Replay belongs in the
 * per-page "refetch on reconnect" path that the iOS
 * `useWSSubscriptions` hook wires up.
 */
import connection from '@ohos.net.connection';
import { BusinessError } from '@ohos.base';
import { wsClient } from './ws-client';

type NetState = 'unknown' | 'online' | 'offline';

/** Network status snapshot. The `online` flag is fed to the WS
 *  client: a `lost` event drops to `pause`; an `available` event
 *  drops to `resume`. */
export interface NetworkState {
  online: boolean;
  /** Cached link properties — when the device has internet the
   *  `netType` is `'wifi' | 'cellular' | 'ethernet' | ...`. We
   *  keep the raw value so the `networkTypeLabel()` helper can
   *  render a human label without an extra lookup. */
  netType: string | null;
}

class RealtimeLifecycle {
  private state: NetworkState = { online: true, netType: null };
  private inBackground = false;
  private netCallbackId: number | null = null;
  private readonly listeners = new Set<(s: NetworkState) => void>();
  private readonly onReconnectHandlers = new Set<() => void>();

  /**
   * Boot the lifecycle manager. Idempotent: calling twice is a
   * no-op. Mount from `EntryAbility.onWindowStageCreate` AFTER
   * `PreferencesBootstrap.init()` (the WS client reads the auth
   * token from Preferences, so it must be hydrated first).
   */
  boot(): void {
    if (this.netCallbackId !== null) return;
    // Wire the WS client's reconnect event so the cache layer
    // can invalidate per-workspace keys when the link comes
    // back. The client doesn't know about the cache directly —
    // this bridge is the cleanest seam.
    wsClient.onReconnect(() => {
      for (const h of this.onReconnectHandlers) {
        try { h(); } catch (err) { console.warn('[lifecycle] reconnect handler threw', err); }
      }
    });
    this.subscribeNetwork();
    // Best-effort connect — the WS client itself short-circuits
    // if it has no token, so this is safe to call before login.
    wsClient.connect();
  }

  teardown(): void {
    if (this.netCallbackId !== null) {
      try {
        connection.unregisterNetConnCallback(this.netCallbackId);
      } catch { /* noop */ }
      this.netCallbackId = null;
    }
    wsClient.disconnect();
  }

  /**
   * Called from EntryAbility.onBackground. The WS client is
   * `pause`d, not `disconnect`ed — we want the next `resume` to
   * reuse the existing socket if the OS kept it alive.
   */
  onAppBackground(): void {
    this.inBackground = true;
    wsClient.pause();
  }

  /**
   * Called from EntryAbility.onForeground. If the OS dropped the
   * socket while we were paused, the WS client detects the null
   * socket and reconnects in `resume()`. We also re-fire the
   * online state in case the network flipped while the user was
   * away.
   */
  onAppForeground(): void {
    this.inBackground = false;
    wsClient.resume();
  }

  /** Subscribe to network-state transitions. The callback is
   *  fired on every change (including the initial state). The
   *  return value is the unsubscribe. */
  onNetworkChange(listener: (s: NetworkState) => void): () => void {
    this.listeners.add(listener);
    // Fire the current state synchronously so the listener
    // doesn't have to assume an initial value.
    listener(this.state);
    return () => this.listeners.delete(listener);
  }

  /** Subscribe to WS reconnects. The cache layer hooks here to
   *  invalidate per-workspace keys (the iOS pattern in
   *  `useWSSubscriptions`). */
  onReconnect(handler: () => void): () => void {
    this.onReconnectHandlers.add(handler);
    return () => this.onReconnectHandlers.delete(handler);
  }

  /** Snapshot of the current network state. */
  getNetworkState(): NetworkState {
    return this.state;
  }

  /** Whether the app is in the background. Pages usually don't
   *  need this — the WS client handles suspension — but it's
   *  exposed for tests that want to assert the lifecycle. */
  isBackgrounded(): boolean {
    return this.inBackground;
  }

  private subscribeNetwork(): void {
    try {
      this.netCallbackId = connection.registerNetConnCallback({
        onAvailable: (netHandle: connection.NetHandle) => {
          this.updateState({ online: true, netType: netHandle?.netType?.toString?.() ?? null });
          if (!this.inBackground) wsClient.resume();
        },
        onLost: (_netHandle: connection.NetHandle) => {
          this.updateState({ online: false, netType: null });
          wsClient.pause();
        },
        onUnavailable: () => {
          this.updateState({ online: false, netType: null });
          wsClient.pause();
        },
        onBlockStatusChange: (_details: connection.NetBlockStatusInfo) => { /* noop */ }
      });
    } catch (err) {
      // Older HarmonyOS versions (pre-5.0) don't ship
      // `registerNetConnCallback` — degrade gracefully to
      // "always online" rather than crashing the boot.
      const e = err as BusinessError;
      console.warn('[lifecycle] network subscribe failed: code=' + e.code + ' msg=' + e.message);
      this.netCallbackId = null;
    }
  }

  private updateState(next: NetworkState): void {
    if (this.state.online === next.online && this.state.netType === next.netType) return;
    this.state = next;
    for (const l of this.listeners) {
      try { l(next); } catch (err) { console.warn('[lifecycle] listener threw', err); }
    }
  }
}

export const realtimeLifecycle: RealtimeLifecycle = new RealtimeLifecycle();

/** Human label for the current net type. Used by the "you are
 *  offline" banner and by tests that need a stable string. */
export const networkTypeLabel: (s: NetworkState) => string =
  (s: NetworkState): string => {
    if (!s.online) return 'offline';
    switch (s.netType) {
      case '0': return 'cellular';
      case '1': return 'wifi';
      case '3': return 'ethernet';
      default: return s.netType ?? 'online';
    }
  };
