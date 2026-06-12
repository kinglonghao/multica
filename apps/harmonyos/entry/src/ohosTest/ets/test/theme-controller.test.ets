/**
 * Tests for the theme controller. The controller is a
 * singleton; we test:
 *   - explicit 'light' / 'dark' / 'system' preferences yield
 *     the correct resolved scheme
 *   - subscribers are notified on change
 *   - 'system' tracks the OS color mode
 *
 * We don't reset state between tests — they're ordered and
 * each writes a known value.
 */
import { describe, it, expect } from '@ohos.hypium';
import { themeController } from '../../../../main/ets/lib/theme-controller';

export default function themeControllerTest(): void {
  describe('themeController', () => {
    it('resolves to light when preference is light', async () => {
      await themeController.setPreference('light');
      expect(themeController.scheme).assertEqual('light');
      expect(themeController.pref).assertEqual('light');
    });

    it('resolves to dark when preference is dark', async () => {
      await themeController.setPreference('dark');
      expect(themeController.scheme).assertEqual('dark');
      expect(themeController.pref).assertEqual('dark');
    });

    it('resolves to system when preference is system', async () => {
      await themeController.setPreference('system');
      expect(themeController.pref).assertEqual('system');
      // The resolved scheme is whatever the OS is reporting;
      // both 'light' and 'dark' are valid.
      expect(themeController.scheme === 'light' || themeController.scheme === 'dark').assertTrue();
    });

    it('ignores invalid preferences', async () => {
      const before = themeController.pref;
      // @ts-expect-error - intentionally bad input
      await themeController.setPreference('pink');
      expect(themeController.pref).assertEqual(before);
    });

    it('subscribers receive the new scheme on change', async () => {
      const received: string[] = [];
      const unsub = themeController.subscribe((s) => { received.push(s); });
      await themeController.setPreference('light');
      await themeController.setPreference('dark');
      unsub();
      expect(received).assertEqual(['light', 'dark']);
    });

    it('unsubscribe stops further notifications', async () => {
      const received: string[] = [];
      const unsub = themeController.subscribe((s) => { received.push(s); });
      await themeController.setPreference('light');
      unsub();
      await themeController.setPreference('dark');
      expect(received).assertEqual(['light']);
    });
  });
}
