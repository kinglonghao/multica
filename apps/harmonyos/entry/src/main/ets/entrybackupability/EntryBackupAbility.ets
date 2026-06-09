import hilog from '@ohos.hilog';
import { BackupExtensionAbility, BundleVersion } from '@ohos.application.BackupExtensionAbility';

const DOMAIN = 0x0000;
const TAG = 'EntryBackupAbility';

/**
 * No-op backup ability — Multica state lives in the workspace backend, so
 * the local store has nothing worth restoring device-to-device. Registered
 * so `ohos.extension.backup` has a handler; the implementation intentionally
 * does not persist or restore any data.
 */
export default class EntryBackupAbility extends BackupExtensionAbility {
  async onBackup(): Promise<void> {
    hilog.info(DOMAIN, TAG, 'onBackup invoked — nothing to back up');
  }

  async onRestore(bundleVersion: BundleVersion): Promise<void> {
    hilog.info(DOMAIN, TAG, `onRestore invoked for v${bundleVersion.code} — nothing to restore`);
  }
};
