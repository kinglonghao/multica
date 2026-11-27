/**
 * Focused tests for the Settings / Profile parity layer.
 */
import { describe, it, expect } from '@ohos.hypium';
import { authStore } from '../../../../main/ets/data/auth';
import { Preferences } from '../../../../main/ets/data/preferences';
import { detectSystemColorScheme } from '../../../../main/ets/lib/theme-manager';

export default function settingsParityTest(): void {
  describe('theme-manager', () => {
    it('honors persisted light preference', () => {
      const original = Preferences.getThemePref;
      (Preferences as unknown as { getThemePref: typeof original }).getThemePref = () => 'light';
      try {
        expect(detectSystemColorScheme()).assertEqual('light');
      } finally {
        (Preferences as unknown as { getThemePref: typeof original }).getThemePref = original;
      }
    });

    it('honors persisted dark preference', () => {
      const original = Preferences.getThemePref;
      (Preferences as unknown as { getThemePref: typeof original }).getThemePref = () => 'dark';
      try {
        expect(detectSystemColorScheme()).assertEqual('dark');
      } finally {
        (Preferences as unknown as { getThemePref: typeof original }).getThemePref = original;
      }
    });
  });

  describe('authStore.setUser', () => {
    it('replaces the in-memory user snapshot', () => {
      const nextUser = {
        id: 'u-1',
        email: 'user@example.com',
        display_name: 'Updated Name',
        avatar_url: 'https://example.com/avatar.png'
      };
      authStore.setUser(nextUser);
      const state = authStore.getState();
      expect(state.user?.display_name).assertEqual('Updated Name');
      expect(state.user?.avatar_url).assertEqual('https://example.com/avatar.png');
    });
  });

  describe('profile avatar helpers', () => {
    it('marks unchanged display name as clean', () => {
      authStore.setUser({
        id: 'u-1',
        email: 'user@example.com',
        display_name: 'Updated Name',
        avatar_url: null
      });
      const page = new ProfilePage();
      page.displayName = 'Updated Name';
      expect((page as unknown as { hasChanges: () => boolean }).hasChanges()).assertEqual(false);
    });

    it('marks edited display name as dirty', () => {
      authStore.setUser({
        id: 'u-1',
        email: 'user@example.com',
        display_name: 'Updated Name',
        avatar_url: null
      });
      const page = new ProfilePage();
      page.displayName = 'Another Name';
      expect((page as unknown as { hasChanges: () => boolean }).hasChanges()).assertEqual(true);
    });
  });
}
