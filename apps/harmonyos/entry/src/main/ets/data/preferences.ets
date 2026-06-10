import preferences from '@ohos.data.preferences';
import common from '@ohos.app.ability.common';
import { BusinessError } from '@ohos.base';

/**
 * Backing store for sensitive values (auth token) and the user's
 * appearance preference. Mirrors iOS `expo-secure-store`. Persistence
 * lives on disk under the ability context; values are loaded synchronously
 * by the bootstrap into the in-memory `Preferences` singleton below so
 * page `aboutToAppear` hooks never have to await storage.
 *
 * Storage keys (do not rename without a migration step):
 *   - auth_token     : string | null
 *   - user_id        : string | null
 *   - user_email     : string | null
 *   - user_display   : string | null
 *   - user_avatar    : string | null
 *   - ws_id          : string | null   (current workspace uuid)
 *   - ws_slug        : string | null
 *   - theme_pref     : 'light' | 'dark' | 'system' (default 'system')
 */

const STORE_NAME = 'multica_secure_prefs';

const KEY_AUTH_TOKEN = 'auth_token';
const KEY_USER_ID = 'user_id';
const KEY_USER_EMAIL = 'user_email';
const KEY_USER_DISPLAY = 'user_display';
const KEY_USER_AVATAR = 'user_avatar';
const KEY_WS_ID = 'ws_id';
const KEY_WS_SLUG = 'ws_slug';
const KEY_THEME_PREF = 'theme_pref';

interface PreferencesSnapshot {
  authToken: string | null;
  userId: string | null;
  userEmail: string | null;
  userDisplay: string | null;
  userAvatar: string | null;
  workspaceId: string | null;
  workspaceSlug: string | null;
  themePref: 'light' | 'dark' | 'system';
}

const EMPTY_SNAPSHOT: PreferencesSnapshot = {
  authToken: null,
  userId: null,
  userEmail: null,
  userDisplay: null,
  userAvatar: null,
  workspaceId: null,
  workspaceSlug: null,
  themePref: 'system',
};

class PreferencesImpl {
  private store: preferences.Preferences | null = null;
  private snapshot: PreferencesSnapshot = { ...EMPTY_SNAPSHOT };
  private readonly listeners = new Set<(s: PreferencesSnapshot) => void>();

  async init(context: common.Context): Promise<void> {
    if (this.store) return;
    this.store = await preferences.getPreferences(context, STORE_NAME);
    this.snapshot = await this.readSnapshot();
  }

  private async readSnapshot(): Promise<PreferencesSnapshot> {
    if (!this.store) return { ...EMPTY_SNAPSHOT };
    const out: PreferencesSnapshot = { ...EMPTY_SNAPSHOT };
    out.authToken = await this.store.get(KEY_AUTH_TOKEN, '') as string || null;
    out.userId = await this.store.get(KEY_USER_ID, '') as string || null;
    out.userEmail = await this.store.get(KEY_USER_EMAIL, '') as string || null;
    out.userDisplay = await this.store.get(KEY_USER_DISPLAY, '') as string || null;
    out.userAvatar = await this.store.get(KEY_USER_AVATAR, '') as string || null;
    out.workspaceId = await this.store.get(KEY_WS_ID, '') as string || null;
    out.workspaceSlug = await this.store.get(KEY_WS_SLUG, '') as string || null;
    const theme = await this.store.get(KEY_THEME_PREF, 'system') as string;
    out.themePref = (theme === 'light' || theme === 'dark' || theme === 'system') ? theme : 'system';
    return out;
  }

  get<K extends keyof PreferencesSnapshot>(key: K): PreferencesSnapshot[K] {
    return this.snapshot[key];
  }

  subscribe(listener: (s: PreferencesSnapshot) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  private emit(): void {
    for (const l of this.listeners) {
      l(this.snapshot);
    }
  }

  async setAuth(token: string, user: { id: string; email: string; display: string | null; avatar: string | null }): Promise<void> {
    if (!this.store) return;
    await this.store.put(KEY_AUTH_TOKEN, token);
    await this.store.put(KEY_USER_ID, user.id);
    await this.store.put(KEY_USER_EMAIL, user.email);
    await this.store.put(KEY_USER_DISPLAY, user.display ?? '');
    await this.store.put(KEY_USER_AVATAR, user.avatar ?? '');
    await this.store.flush();
    this.snapshot = { ...this.snapshot, authToken: token, userId: user.id, userEmail: user.email, userDisplay: user.display, userAvatar: user.avatar };
    this.emit();
  }

  async setWorkspace(id: string | null, slug: string | null): Promise<void> {
    if (!this.store) return;
    await this.store.put(KEY_WS_ID, id ?? '');
    await this.store.put(KEY_WS_SLUG, slug ?? '');
    await this.store.flush();
    this.snapshot = { ...this.snapshot, workspaceId: id, workspaceSlug: slug };
    this.emit();
  }

  async setThemePref(pref: 'light' | 'dark' | 'system'): Promise<void> {
    if (!this.store) return;
    await this.store.put(KEY_THEME_PREF, pref);
    await this.store.flush();
    this.snapshot = { ...this.snapshot, themePref: pref };
    this.emit();
  }

  async clearAuth(): Promise<void> {
    if (!this.store) return;
    const keys = [KEY_AUTH_TOKEN, KEY_USER_ID, KEY_USER_EMAIL, KEY_USER_DISPLAY, KEY_USER_AVATAR, KEY_WS_ID, KEY_WS_SLUG];
    for (const k of keys) {
      await this.store.delete(k);
    }
    await this.store.flush();
    this.snapshot = { ...EMPTY_SNAPSHOT };
    this.emit();
  }
}

export const Preferences: PreferencesImpl = new PreferencesImpl();

/**
 * One-shot bootstrap that EntryAbility awaits in onWindowStageCreate.
 * Initializing here means the very first frame of Index.ets reads
 * authToken from a synchronously available value — no "flash of
 * logged-out state" before the splash fades.
 */
export class PreferencesBootstrap {
  static async init(context: common.Context): Promise<void> {
    try {
      await Preferences.init(context);
    } catch (err) {
      const e = err as BusinessError;
      throw new Error(`Preferences bootstrap failed: code=${e.code} msg=${e.message}`);
    }
  }
}
