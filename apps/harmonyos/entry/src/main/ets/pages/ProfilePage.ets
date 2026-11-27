import promptAction from '@ohos.promptAction';
import { camera, cameraPicker as picker } from '@kit.CameraKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import type common from '@ohos.app.ability.common';
import { authStore } from '../data/auth';
import { api, UploadFileAsset } from '../data/api';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Avatar } from '../components/ui/Avatar';
import { MulticaButton } from '../components/ui/Button';

const MAX_AVATAR_BYTES = 5 * 1024 * 1024;

class CameraCaptureTarget {
  filePath: string = '';
  fileName: string = '';
  profile: picker.PickerProfile = {} as picker.PickerProfile;
}

class ActionMenuButton {
  text: string = '';
  color?: Color;
}

@ComponentV2
export struct ProfilePage {
  @Local scheme: ColorScheme = 'light';
  @Local displayName: string = '';
  @Local email: string = '';
  @Local saving: boolean = false;
  @Local uploading: boolean = false;
  @Local errorMessage: string = '';
  @Local success: boolean = false;
  @Local avatarUrl: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const user = authStore.getState().user;
    this.displayName = user?.display_name ?? user?.email ?? '';
    this.email = user?.email ?? '';
    this.avatarUrl = user?.avatar_url ?? '';
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private getHostContext(): common.Context | undefined {
    const uiContext = this.getUIContext();
    return uiContext ? uiContext.getHostContext() as common.Context : undefined;
  }

  private hasChanges(): boolean {
    const user = authStore.getState().user;
    const currentName = user?.display_name ?? user?.email ?? '';
    return this.displayName.trim().length > 0 && this.displayName.trim() !== currentName;
  }

  private makeActionButton(text: string): promptAction.Button {
    const button: promptAction.Button = { text } as promptAction.Button;
    return button;
  }

  private async handleAvatarPick(): Promise<void> {
    this.errorMessage = '';
    const hasAvatar = this.avatarUrl.trim().length > 0;
    const buttons: [promptAction.Button, promptAction.Button, promptAction.Button?, promptAction.Button?] = hasAvatar
      ? [
          this.makeActionButton('Take Photo'),
          this.makeActionButton('Choose from Library'),
          this.makeActionButton('Remove Photo'),
          this.makeActionButton('Cancel')
        ]
      : [
          this.makeActionButton('Take Photo'),
          this.makeActionButton('Choose from Library'),
          this.makeActionButton('Cancel')
        ];
    try {
      const result = await promptAction.showActionMenu({
        title: 'Profile photo',
        buttons
      });
      if (result.index === 0) {
        await this.pickFromCamera();
        return;
      }
      if (result.index === 1) {
        await this.pickFromLibrary();
        return;
      }
      if (hasAvatar && result.index === 2) {
        await this.removeAvatar();
      }
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Could not open photo menu.';
    }
  }

  private async pickFromCamera(): Promise<void> {
    const context = this.getHostContext();
    if (!context) {
      this.errorMessage = 'Camera is unavailable right now.';
      return;
    }
    try {
      const capture = this.createCameraTarget(context);
      const result = await picker.pick(context, [picker.PickerMediaType.PHOTO], capture.profile);
      if (result.resultCode !== 0 || !result.resultUri) return;
      await this.uploadAvatar({
        uri: capture.filePath,
        name: capture.fileName,
        type: 'image/jpeg'
      });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Could not take photo.';
    }
  }

  private createCameraTarget(context: common.Context): CameraCaptureTarget {
    const target = new CameraCaptureTarget();
    target.fileName = `avatar-${Date.now()}.jpg`;
    target.filePath = `${context.filesDir}/${target.fileName}`;
    try {
      fileIo.createRandomAccessFileSync(target.filePath, fileIo.OpenMode.CREATE);
    } catch (err) {
      throw err instanceof Error ? err : new Error('Failed to prepare camera target file');
    }
    const saveUri = fileUri.getUriFromPath(target.filePath);
    const profile = {} as picker.PickerProfile;
    profile.cameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
    profile.saveUri = saveUri;
    target.profile = profile;
    return target;
  }

  private async pickFromLibrary(): Promise<void> {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result = await photoViewPicker.select(photoSelectOptions);
      const uri = result.photoUris && result.photoUris.length > 0 ? result.photoUris[0] : '';
      if (!uri) return;
      const stat = fileIo.statSync(uri);
      if (stat.size > MAX_AVATAR_BYTES) {
        this.errorMessage = 'Pick an image under 5 MB.';
        return;
      }
      await this.uploadAvatar({
        uri,
        name: `avatar-${Date.now()}.jpg`,
        type: 'image/jpeg'
      });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Could not choose photo.';
    }
  }

  private async uploadAvatar(file: UploadFileAsset): Promise<void> {
    this.uploading = true;
    this.errorMessage = '';
    this.success = false;
    try {
      const attachment = await api.uploadFile('me', file);
      const user = await api.updateMe({ avatar_url: attachment.url });
      authStore.setUser(user);
      this.avatarUrl = user.avatar_url ?? '';
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Could not upload avatar.';
    } finally {
      this.uploading = false;
    }
  }

  private async removeAvatar(): Promise<void> {
    this.uploading = true;
    this.errorMessage = '';
    this.success = false;
    try {
      const user = await api.updateMe({ avatar_url: '' });
      authStore.setUser(user);
      this.avatarUrl = user.avatar_url ?? '';
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Could not remove avatar.';
    } finally {
      this.uploading = false;
    }
  }

  private async save(): Promise<void> {
    if (!this.hasChanges()) return;
    this.saving = true;
    this.errorMessage = '';
    this.success = false;
    try {
      const user = await api.updateMe({ display_name: this.displayName.trim() });
      authStore.setUser(user);
      this.displayName = user.display_name ?? user.email ?? '';
      this.email = user.email;
      this.avatarUrl = user.avatar_url ?? '';
      this.success = true;
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : 'Failed to update profile';
    } finally {
      this.saving = false;
    }
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Column() {
            Row() {
              Avatar({ name: this.displayName || this.email, url: this.avatarUrl, avatarSize: 96, scheme: this.scheme })
            }
            .onClick(() => { void this.handleAvatarPick(); })

            MulticaText({
              value: this.uploading ? 'Uploading photo…' : 'Tap to change photo',
              scheme: this.scheme,
              textSize: 'xs',
              color: 'mutedForeground'
            })
              .margin({ top: space('3') })
          }
          .width('100%')
          .padding({ top: space('6') })
          .alignItems(HorizontalAlign.Center)

          Row() {}
            .width('100%')
            .height(1)
            .margin({ top: space('6') })
            .backgroundColor(String(themeTokens(this.scheme).border))

          Column() {
            Column() {
              MulticaText({
                value: 'Name',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
              TextInput({ placeholder: 'Your name', text: this.displayName })
                .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
                .fontColor(String(themeTokens(this.scheme).foreground))
                .backgroundColor(String(themeTokens(this.scheme).card))
                .borderRadius(RADIUS.md)
                .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
                .margin({ top: space('2') })
                .border({ width: 1, color: String(themeTokens(this.scheme).border) })
                .onChange((value: string) => {
                  this.displayName = value;
                  this.success = false;
                })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)

            Column() {
              MulticaText({
                value: 'Email',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
              Row() {
                MulticaText({
                  value: this.email || '—',
                  scheme: this.scheme,
                  textSize: 'sm',
                  color: 'mutedForeground'
                })
              }
              .width('100%')
              .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
              .margin({ top: space('2') })
              .backgroundColor(String(themeTokens(this.scheme).card))
              .borderRadius(RADIUS.md)
              .border({ width: 1, color: String(themeTokens(this.scheme).border) })

              MulticaText({
                value: 'Email is set at sign-up and can’t be changed here.',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
                .margin({ top: space('2') })
            }
            .width('100%')
            .margin({ top: space('4') })
            .alignItems(HorizontalAlign.Start)

            if (this.errorMessage) {
              MulticaText({
                value: this.errorMessage,
                scheme: this.scheme,
                textSize: 'xs',
                color: 'destructive'
              })
                .margin({ top: space('3') })
            }

            if (this.success) {
              MulticaText({
                value: 'Saved',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'success'
              })
                .margin({ top: space('3') })
            }
          }
          .width('100%')
          .padding({ left: space('4'), right: space('4'), top: space('6'), bottom: space('8') })
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Row() {
        MulticaButton({
          label: this.saving ? 'Saving…' : 'Save',
          scheme: this.scheme,
          variant: 'primary',
          fullWidth: true,
          disabled: this.saving || !this.hasChanges(),
          onTap: () => { void this.save(); }
        })
      }
      .width('100%')
      .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('4') })
      .backgroundColor(String(themeTokens(this.scheme).background))
      .border({
        width: { top: 1 },
        color: String(themeTokens(this.scheme).border)
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
