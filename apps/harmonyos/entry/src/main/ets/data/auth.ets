import { api, ApiError } from './api';
import { Preferences } from './preferences';
import { LoginResponse, User } from '../models/types';

/**
 * Auth state container. Mirrors apps/mobile/data/auth-store.ts but with
 * a simpler manual subscription model — HarmonyOS has no Zustand, so we
 * hold @State-friendly plain object and notify subscribers.
 *
 * Lifecycle:
 *   - `initialize()` runs once on app boot (from Index.ets aboutToAppear).
 *     If a token is already in secure storage, it calls `getMe()` to
 *     refresh the user record and resolve the boot promise.
 *   - `requestOtp(email)` triggers an email OTP, no state change.
 *   - `verifyOtp(email, code)` posts the code, stores token+user,
 *     sets `bootState = 'authed'`.
 *   - `logout()` clears the token + user, sets `bootState = 'unauthed'`.
 */

export type BootState = 'uninitialized' | 'unauthed' | 'authed';

interface AuthSnapshot {
  state: BootState;
  user: User | null;
  token: string | null;
  error: string | null;
}

type Listener = (s: AuthSnapshot) => void;

class AuthStore {
  private snapshot: AuthSnapshot = {
    state: 'uninitialized',
    user: null,
    token: null,
    error: null
  };
  private readonly listeners = new Set<Listener>();

  getState(): AuthSnapshot {
    return this.snapshot;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    listener(this.snapshot);
    return () => this.listeners.delete(listener);
  }

  private set(patch: Partial<AuthSnapshot>): void {
    this.snapshot = { ...this.snapshot, ...patch };
    for (const l of this.listeners) l(this.snapshot);
  }

  async initialize(): Promise<void> {
    const token = Preferences.get('authToken');
    const userId = Preferences.get('userId');
    if (!token || !userId) {
      this.set({ state: 'unauthed', token: null, user: null, error: null });
      return;
    }
    this.set({ state: 'authed', token, user: this.snapshot.user });
    try {
      const user = await api.getMe();
      this.set({ user });
    } catch (err) {
      // 401 here means the token is dead — let the onUnauthorized callback
      // clear it; just don't propagate the throw.
      if (err instanceof ApiError && err.status === 401) {
        return;
      }
      console.warn('[auth] getMe on boot failed, treating as unauthed:', err);
      this.set({ state: 'unauthed', user: null, error: null });
    }
  }

  async requestOtp(email: string): Promise<void> {
    try {
      this.set({ error: null });
      await api.requestOtp(email);
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to send code';
      this.set({ error: msg });
      throw err;
    }
  }

  async verifyOtp(email: string, code: string): Promise<void> {
    try {
      this.set({ error: null });
      const res: LoginResponse = await api.verifyOtp(email, code);
      await Preferences.setAuth(res.token, {
        id: res.user.id,
        email: res.user.email,
        display: res.user.display_name ?? null,
        avatar: res.user.avatar_url ?? null
      });
      api.setOptions({ onUnauthorized: this.handleUnauthorized });
      this.set({ state: 'authed', user: res.user, token: res.token, error: null });
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Verification failed';
      this.set({ error: msg });
      throw err;
    }
  }

  async logout(): Promise<void> {
    await Preferences.clearAuth();
    this.set({ state: 'unauthed', user: null, token: null, error: null });
  }

  /**
   * Idempotent: if multiple requests 401 simultaneously (e.g. session
   * just expired server-side), only the first one runs the clear+navigate
   * sequence. Mirrors the `signingOutRef` pattern in the iOS
   * `AuthInitializer` (apps/mobile/app/_layout.tsx).
   */
  private signingOut = false;
  handleUnauthorized = (): void => {
    if (this.signingOut) return;
    this.signingOut = true;
    void (async () => {
      await Preferences.clearAuth();
      this.set({ state: 'unauthed', user: null, token: null, error: null });
      // Routed via globalEvents below so the page router can pick it up.
      globalEvents.emit('auth:required');
      setTimeout(() => { this.signingOut = false; }, 0);
    })();
  };
}

export const authStore: AuthStore = new AuthStore();

/**
 * Minimal global event bus. ArkUI's router has no global event channel,
 * so any non-page-scoped notification goes through here. Kept tiny on
 * purpose: `auth:required` (forced sign-out) and `workspace:changed`
 * (workspaces-switched event) are the only events the app fires today.
 */
class GlobalEvents {
  private readonly listeners = new Map<string, Set<() => void>>();

  on(event: string, handler: () => void): () => void {
    let set = this.listeners.get(event);
    if (!set) {
      set = new Set();
      this.listeners.set(event, set);
    }
    set.add(handler);
    return () => set!.delete(handler);
  }

  emit(event: string): void {
    const set = this.listeners.get(event);
    if (!set) return;
    for (const h of set) h();
  }
}

export const globalEvents: GlobalEvents = new GlobalEvents();

// Wire the 401 handler into the API client. Idempotent — calling
// setOptions again later just merges.
api.setOptions({ onUnauthorized: authStore.handleUnauthorized });
