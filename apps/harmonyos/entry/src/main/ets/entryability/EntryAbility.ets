import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import { PreferencesBootstrap } from '../data/preferences';
import { themeController } from '../lib/theme-controller';
import { localeController } from '../lib/locale';

const DOMAIN = 0x0000;
const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageCreate');

    // Boot the secure preferences backing store before the first page loads.
    // Auth tokens and theme preferences live there, and pages read them
    // synchronously in their aboutToAppear — initializing here means the
    // first frame is painted with the right values, not a flash of the
    // default state.
    //
    // INTENTIONAL FALLBACK: if preferences init fails (corrupt store,
    // permission denied, etc.) we log the error and continue to
    // loadContent(). The Index page's boot sequence will find no token
    // and route to LoginPage — a user can still sign in (which writes
    // a fresh preferences record) and the app stays functional.
    // Crashing the ability here would leave the user with a dead app
    // and no recovery path.
    try {
      await PreferencesBootstrap.init(this.context);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'preferences init failed: %{public}s', JSON.stringify(err));
    }

    // Init the theme + locale controllers from the same persisted
    // snapshot. Both are no-ops if the controllers are already
    // initialized (e.g. after a hot reload).
    try {
      await themeController.init(this.context);
      await localeController.init(this.context);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'controller init failed: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load Index. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Index page loaded.');
    });

    // Edge-to-edge: let content paint behind the status bar. Matches the
    // iOS client's "Lock the look" — we want a single, immersive canvas
    // and rely on safe-area insets inside the page chrome to avoid the
    // status bar and navigation gesture areas.
    try {
      const win = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
    }

    // Wire the system-appearance listener now that the window exists.
    // Pages re-pull `themeController.scheme` via their subscribers; this
    // just gives us the trigger when the OS theme flips while the app
    // is foregrounded.
    themeController.attachWindowStage(windowStage);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onBackground');
  }
};
