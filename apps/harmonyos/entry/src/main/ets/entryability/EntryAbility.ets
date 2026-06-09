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
