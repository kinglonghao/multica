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
 *   - locale_pref    : 'en' | 'zh' (default 'en')
 *   - chat_draft_<id>: string          (per-chat-session draft body)
 *   - new_issue_draft: string          (new-issue form body)
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
const KEY_LOCALE_PREF = 'locale_pref';
const KEY_NEW_ISSUE_DRAFT = 'new_issue_draft';
const KEY_CHAT_DRAFT_PREFIX = 'chat_draft_';

interface PreferencesSnapshot {
  authToken: string | null;
  userId: string | null;
  userEmail: string | null;
  userDisplay: string | null;
  userAvatar: string | null;
  workspaceId: string | null;
  workspaceSlug: string | null;
  themePref: 'light' | 'dark' | 'system';
  localePref: 'en' | 'zh';
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
  localePref: 'en',
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
    const locale = await this.store.get(KEY_LOCALE_PREF, 'en') as string;
    out.localePref = (locale === 'en' || locale === 'zh') ? locale : 'en';
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

  async setLocalePref(pref: 'en' | 'zh'): Promise<void> {
    if (!this.store) return;
    await this.store.put(KEY_LOCALE_PREF, pref);
    await this.store.flush();
    this.snapshot = { ...this.snapshot, localePref: pref };
    this.emit();
  }

  /**
   * Read a chat-session draft body. The session id is a UUID;
   * we namespace the key as `chat_draft_<id>` so each session
   * gets its own slot.
   */
  async getChatDraft(sessionId: string): Promise<string> {
    if (!this.store) return '';
    return (await this.store.get(KEY_CHAT_DRAFT_PREFIX + sessionId, '') as string) || '';
  }

  async setChatDraft(sessionId: string, body: string): Promise<void> {
    if (!this.store) return;
    const key = KEY_CHAT_DRAFT_PREFIX + sessionId;
    if (body.length === 0) {
      await this.store.delete(key);
    } else {
      await this.store.put(key, body);
    }
    await this.store.flush();
  }

  /**
   * Read/write the new-issue form draft. Stored as a single
   * JSON string so a future field can be added without
   * bumping the key.
   */
  async getNewIssueDraft(): Promise<string> {
    if (!this.store) return '';
    return (await this.store.get(KEY_NEW_ISSUE_DRAFT, '') as string) || '';
  }

  async setNewIssueDraft(body: string): Promise<void> {
    if (!this.store) return;
    if (body.length === 0) {
      await this.store.delete(KEY_NEW_ISSUE_DRAFT);
    } else {
      await this.store.put(KEY_NEW_ISSUE_DRAFT, body);
    }
    await this.store.flush();
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
