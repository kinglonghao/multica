/**
 * LocaleController — owns the user-facing language preference
 * ('en' | 'zh') and the active translation table.
 *
 * Why a singleton and not a hook? Same reasoning as
 * `theme-controller.ets`: pages already hold their own
 * `@Local version: number` and re-render on every update; the
 * controller's job is the shared translation table and notifying
 * subscribers so each page re-pulls.
 *
 * Source of truth is `Preferences.localePref` (string key
 * 'locale_pref'). The default is 'system' which resolves via
 * `getConfigurationSync().languageCode` — if it's 'zh' we use
 * Chinese, otherwise English.
 *
 * We intentionally keep the dictionaries flat (string -> string)
 * and pass them through a `t(key, params?)` helper that does
 * simple `{{name}}` substitution. ArkTS strict forbids dynamic
 * bracket access, so we encode the lookup as a switch over a
 * union of known keys.
 *
 * Adding a new key:
 *   1. Add the key to `LocaleKey` below.
 *   2. Add the English string in the `EN` table.
 *   3. Add the Chinese string in the `ZH` table.
 *   4. Use `t('key_name')` at the call site.
 *
 * The set of keys is intentionally small and page-local — chat
 * tab labels, more tab labels, common buttons, settings page
 * labels. This is NOT a port of `packages/views/locales/`; that
 * catalog is web/desktop owned and would balloon the harmonyos
 * build. HarmonyOS is its own platform with its own i18n
 * surface; the goal is just "at least 中英双语打通".
 */
import { Preferences } from '../data/preferences';
import common from '@ohos.app.ability.common';

export type LocalePreference = 'en' | 'zh';
export type SupportedLocale = 'en' | 'zh';

const DEFAULT_LOCALE: SupportedLocale = 'en';

/**
 * Union of every string the harmonyos app translates. Adding a
 * key here is a forcing function to add the value to BOTH
 * dictionaries — the switch in `t()` would not return a typed
 * value for an unlisted key.
 */
export type LocaleKey =
  // Tabs
  | 'tab_inbox'
  | 'tab_my_issues'
  | 'tab_chat'
  | 'tab_more'
  // Common
  | 'common_cancel'
  | 'common_save'
  | 'common_delete'
  | 'common_confirm'
  | 'common_loading'
  | 'common_retry'
  | 'common_settings'
  | 'common_sign_out'
  | 'common_back'
  | 'common_yes'
  | 'common_no'
  | 'common_done'
  | 'common_close'
  // Inbox
  | 'inbox_title'
  | 'inbox_empty'
  | 'inbox_loading_failed'
  // My Issues
  | 'my_issues_title'
  | 'my_issues_empty'
  // Chat
  | 'chat_title'
  | 'chat_empty'
  | 'chat_composer_placeholder'
  | 'chat_send'
  | 'chat_new_chat'
  | 'chat_no_messages'
  | 'chat_message_failed'
  | 'chat_message_failed_retry'
  // More
  | 'more_title'
  | 'more_section_navigate'
  | 'more_section_account'
  | 'more_projects'
  | 'more_issues'
  | 'more_pinned'
  | 'more_agents'
  | 'more_notifications'
  | 'more_profile'
  | 'more_switch_workspace'
  | 'more_workspace_label'
  | 'more_sign_out_confirm_title'
  | 'more_sign_out_confirm_message'
  | 'more_sign_out_failed'
  // Settings
  | 'settings_title'
  | 'settings_appearance'
  | 'settings_appearance_light'
  | 'settings_appearance_dark'
  | 'settings_appearance_system'
  | 'settings_language'
  | 'settings_language_en'
  | 'settings_language_zh'
  | 'settings_account'
  | 'settings_about'
  // Login
  | 'login_title'
  | 'login_subtitle'
  | 'login_email_placeholder'
  | 'login_continue'
  | 'login_failed'
  // New issue
  | 'new_issue_title'
  | 'new_issue_title_placeholder'
  | 'new_issue_description_placeholder'
  | 'new_issue_attach'
  | 'new_issue_submit'
  | 'new_issue_draft_saved'
  | 'new_issue_failed'
  // Workspace label
  | 'workspace_label'
  | 'workspace_no_workspace'
  | 'workspace_create'
  // Misc
  | 'language_en_label'
  | 'language_zh_label'
  | 'theme_light_label'
  | 'theme_dark_label'
  | 'theme_system_label';

/* eslint-disable @typescript-eslint/quotes */
const EN: Record<LocaleKey, string> = {
  tab_inbox: 'Inbox',
  tab_my_issues: 'My Issues',
  tab_chat: 'Chat',
  tab_more: 'More',

  common_cancel: 'Cancel',
  common_save: 'Save',
  common_delete: 'Delete',
  common_confirm: 'Confirm',
  common_loading: 'Loading…',
  common_retry: 'Try again',
  common_settings: 'Settings',
  common_sign_out: 'Sign out',
  common_back: 'Back',
  common_yes: 'Yes',
  common_no: 'No',
  common_done: 'Done',
  common_close: 'Close',

  inbox_title: 'Inbox',
  inbox_empty: 'No new notifications',
  inbox_loading_failed: 'Could not load inbox',

  my_issues_title: 'My Issues',
  my_issues_empty: 'No issues assigned to you yet',

  chat_title: 'Chat',
  chat_empty: 'No chat sessions yet',
  chat_composer_placeholder: 'Message…',
  chat_send: 'Send',
  chat_new_chat: 'New chat',
  chat_no_messages: 'Send the first message to start the conversation',
  chat_message_failed: 'Failed to send',
  chat_message_failed_retry: 'Retry',

  more_title: 'More',
  more_section_navigate: 'Navigate',
  more_section_account: 'Account',
  more_projects: 'Projects',
  more_issues: 'Issues',
  more_pinned: 'Pinned',
  more_agents: 'Agents',
  more_notifications: 'Notifications',
  more_profile: 'Profile',
  more_switch_workspace: 'Switch workspace',
  more_workspace_label: 'Workspace',
  more_sign_out_confirm_title: 'Sign out?',
  more_sign_out_confirm_message: 'You will need to sign in again to use Multica on this device.',
  more_sign_out_failed: 'Sign-out failed — please try again',

  settings_title: 'Settings',
  settings_appearance: 'Appearance',
  settings_appearance_light: 'Light',
  settings_appearance_dark: 'Dark',
  settings_appearance_system: 'System',
  settings_language: 'Language',
  settings_language_en: 'English',
  settings_language_zh: '中文',
  settings_account: 'Account',
  settings_about: 'About',

  login_title: 'Sign in to Multica',
  login_subtitle: 'Enter your email to receive a one-time code.',
  login_email_placeholder: 'you@company.com',
  login_continue: 'Continue',
  login_failed: 'Sign-in failed. Please try again.',

  new_issue_title: 'New issue',
  new_issue_title_placeholder: 'Issue title',
  new_issue_description_placeholder: 'Describe the issue (Markdown supported)',
  new_issue_attach: 'Attach',
  new_issue_submit: 'Create issue',
  new_issue_draft_saved: 'Draft saved',
  new_issue_failed: 'Could not create issue',

  workspace_label: 'Workspace',
  workspace_no_workspace: 'No workspace selected',
  workspace_create: 'Create workspace',

  language_en_label: 'English',
  language_zh_label: '中文',
  theme_light_label: 'Light',
  theme_dark_label: 'Dark',
  theme_system_label: 'System'
};

const ZH: Record<LocaleKey, string> = {
  tab_inbox: '收件箱',
  tab_my_issues: '我的事项',
  tab_chat: '对话',
  tab_more: '更多',

  common_cancel: '取消',
  common_save: '保存',
  common_delete: '删除',
  common_confirm: '确认',
  common_loading: '加载中…',
  common_retry: '重试',
  common_settings: '设置',
  common_sign_out: '退出登录',
  common_back: '返回',
  common_yes: '是',
  common_no: '否',
  common_done: '完成',
  common_close: '关闭',

  inbox_title: '收件箱',
  inbox_empty: '暂无新通知',
  inbox_loading_failed: '无法加载收件箱',

  my_issues_title: '我的事项',
  my_issues_empty: '还没有分配给你的事项',

  chat_title: '对话',
  chat_empty: '暂无会话',
  chat_composer_placeholder: '输入消息…',
  chat_send: '发送',
  chat_new_chat: '新建对话',
  chat_no_messages: '发送第一条消息开始对话',
  chat_message_failed: '发送失败',
  chat_message_failed_retry: '重试',

  more_title: '更多',
  more_section_navigate: '导航',
  more_section_account: '账户',
  more_projects: '项目',
  more_issues: '事项',
  more_pinned: '已置顶',
  more_agents: '智能体',
  more_notifications: '通知',
  more_profile: '个人资料',
  more_switch_workspace: '切换工作区',
  more_workspace_label: '工作区',
  more_sign_out_confirm_title: '退出登录？',
  more_sign_out_confirm_message: '你将需要重新登录才能在此设备上使用 Multica。',
  more_sign_out_failed: '退出失败，请重试',

  settings_title: '设置',
  settings_appearance: '外观',
  settings_appearance_light: '浅色',
  settings_appearance_dark: '深色',
  settings_appearance_system: '跟随系统',
  settings_language: '语言',
  settings_language_en: 'English',
  settings_language_zh: '中文',
  settings_account: '账户',
  settings_about: '关于',

  login_title: '登录 Multica',
  login_subtitle: '输入邮箱以获取一次性验证码。',
  login_email_placeholder: 'you@company.com',
  login_continue: '继续',
  login_failed: '登录失败，请重试。',

  new_issue_title: '新建事项',
  new_issue_title_placeholder: '事项标题',
  new_issue_description_placeholder: '描述事项（支持 Markdown）',
  new_issue_attach: '附件',
  new_issue_submit: '创建事项',
  new_issue_draft_saved: '草稿已保存',
  new_issue_failed: '无法创建事项',

  workspace_label: '工作区',
  workspace_no_workspace: '未选择工作区',
  workspace_create: '创建工作区',

  language_en_label: 'English',
  language_zh_label: '中文',
  theme_light_label: '浅色',
  theme_dark_label: '深色',
  theme_system_label: '跟随系统'
};

const TABLES: Record<SupportedLocale, Record<LocaleKey, string>> = { en: EN, zh: ZH };

class LocaleControllerImpl {
  private preference: LocalePreference = 'en';
  private resolved: SupportedLocale = DEFAULT_LOCALE;
  private readonly listeners = new Set<(locale: SupportedLocale) => void>();
  private initialized = false;

  async init(context: common.UIAbilityContext): Promise<void> {
    if (this.initialized) return;
    this.initialized = true;

    const saved = Preferences.get('localePref');
    if (saved === 'en' || saved === 'zh') {
      this.preference = saved;
    }
    this.resolved = this.computeResolved(this.preference, this.readOsLocale(context));
  }

  get locale(): SupportedLocale {
    return this.resolved;
  }

  get pref(): LocalePreference {
    return this.preference;
  }

  subscribe(listener: (locale: SupportedLocale) => void): () => void {
    this.listeners.add(listener);
    return () => { this.listeners.delete(listener); };
  }

  async setPreference(p: LocalePreference): Promise<void> {
    if (p !== 'en' && p !== 'zh') return;
    if (p === this.preference) return;
    this.preference = p;
    this.resolved = p; // explicit user choice always wins
    await Preferences.setLocalePref(p);
    this.emit();
  }

  private computeResolved(pref: LocalePreference, os: SupportedLocale): SupportedLocale {
    return pref;
  }

  private readOsLocale(ctx: common.UIAbilityContext | null): SupportedLocale {
    try {
      const fallback = ctx ?? globalThis.abilityContext as common.UIAbilityContext | null;
      if (fallback) {
        const cfg = fallback.resourceManager.getConfigurationSync();
        // languageCode is e.g. 'zh', 'en', 'zh-CN', etc.
        const lang = cfg?.language as string | undefined;
        if (typeof lang === 'string' && lang.toLowerCase().startsWith('zh')) {
          return 'zh';
        }
      }
    } catch { /* fall through */ }
    return DEFAULT_LOCALE;
  }

  private emit(): void {
    for (const l of this.listeners) {
      try { l(this.resolved); } catch (err) {
        console.warn('[locale-controller] subscriber threw', err);
      }
    }
  }
}

export const localeController: LocaleControllerImpl = new LocaleControllerImpl();

/**
 * Translation helper. Call sites use `t('inbox_title')` and
 * get back the active locale's string. Static key type keeps
 * ArkTS happy — the switch is exhaustive and falls through to
 * the key itself (a sentinel that surfaces a missing
 * translation during development).
 */
export const t: (key: LocaleKey) => string =
  (key: LocaleKey): string => {
    const table = TABLES[localeController.locale];
    // All keys must be present in BOTH tables by construction; the
    // nullish fallback guards against a half-merged refactor.
    return table[key] ?? key;
  };
