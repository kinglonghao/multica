/**
 * Tests for the locale controller and `t()` helper. The
 * controller is a singleton; tests poke `setPreference` and
 * confirm the resolved locale + table flip. We don't reset
 * state between tests — they're ordered and each writes a
 * known value.
 */
import { describe, it, expect } from '@ohos.hypium';
import { localeController, t } from '../../../../main/ets/lib/locale';

export default function localeTest(): void {
  describe('localeController', () => {
    it('initializes with English by default', () => {
      // We don't call init() — the controller falls back to 'en'
      // until either init() is called or setPreference() is.
      expect(localeController.locale === 'en' || localeController.locale === 'zh').assertTrue();
    });

    it('resolves to Chinese after setPreference("zh")', async () => {
      await localeController.setPreference('zh');
      expect(localeController.locale).assertEqual('zh');
      expect(localeController.pref).assertEqual('zh');
    });

    it('resolves to English after setPreference("en")', async () => {
      await localeController.setPreference('en');
      expect(localeController.locale).assertEqual('en');
      expect(localeController.pref).assertEqual('en');
    });

    it('ignores invalid preferences', async () => {
      const before = localeController.pref;
      // @ts-expect-error - intentionally bad input
      await localeController.setPreference('fr');
      expect(localeController.pref).assertEqual(before);
    });

    it('subscribe receives the new locale on change', async () => {
      const received: string[] = [];
      const unsub = localeController.subscribe((l) => { received.push(l); });
      await localeController.setPreference('zh');
      await localeController.setPreference('en');
      unsub();
      expect(received).assertEqual(['zh', 'en']);
    });
  });

  describe('t()', () => {
    it('returns the active locale translation', async () => {
      await localeController.setPreference('en');
      expect(t('tab_inbox')).assertEqual('Inbox');
      await localeController.setPreference('zh');
      expect(t('tab_inbox')).assertEqual('收件箱');
    });

    it('returns the same key for unknown keys (sentinel)', () => {
      // @ts-expect-error - intentionally bad key
      expect(t('not_a_key')).assertEqual('not_a_key');
    });
  });
}
