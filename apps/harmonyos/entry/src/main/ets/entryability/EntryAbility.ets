import UIAbility from '@ohos.app.ability.UIAbility';
import hilog from '@ohos.hilog';
import window from '@ohos.window';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import Want from '@ohos.app.ability.Want';
import { BusinessError } from '@ohos.base';
import { PreferencesBootstrap } from '../data/preferences';

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

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load Index. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, '%{public}s', 'Index page loaded.');
    });

    // Keep edge-to-edge layout, but control system bar colors explicitly.
    // Normal window layout introduced a larger white top bar on HarmonyOS.
    try {
      const win = windowStage.getMainWindowSync();
      win.setWindowLayoutFullScreen(true);
      win.setWindowSystemBarProperties({
        statusBarColor: '#0B0B0C',
        navigationBarColor: '#0B0B0C',
        statusBarContentColor: '#E5E7EB',
        navigationBarContentColor: '#E5E7EB'
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'setWindowLayoutFullScreen failed: %{public}s', JSON.stringify(err));
    }
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
