import { appNavigation } from '../data/navigation';
import { createProjectResource } from '../mutations/project';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { MulticaButton } from '../components/ui/Button';
import { PickerRow } from '../components/issue/PickerRow';

/**
 * Add-resource form. Pushed from the project detail page's
 * "Resources" section. Mirrors the iOS formSheet pattern
 * (`apps/mobile/app/(app)/[workspace]/projects/[id]/resources/new.tsx`).
 *
 * The form has three fields:
 *   - name (required)
 *   - type (one of: link, doc, repo, design, other)
 *   - url  (optional — left blank for docs / designs where the
 *           resource is uploaded later)
 *
 * Save path: `createProjectResource` (mutation in
 * `mutations/project.ets`) → returns the server-issued row.
 * We push it into the project-resources cache on the way out
 * so the detail page renders the new row on its next read.
 */

const RESOURCE_TYPES: ReadonlyArray<{ value: string; label: string }> = [
  { value: 'link', label: 'Link' },
  { value: 'doc', label: 'Document' },
  { value: 'repo', label: 'Repository' },
  { value: 'design', label: 'Design' },
  { value: 'other', label: 'Other' }
];

@ComponentV2
export struct AddProjectResourcePage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local name: string = '';
  @Local url: string = '';
  @Local resourceType: string = 'link';
  @Local busy: boolean = false;
  @Local errorMsg: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  aboutToDisappear(): void { /* noop */ }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private async save(): Promise<void> {
    if (this.busy) return;
    const name = this.name.trim();
    if (!name) {
      this.errorMsg = 'Name is required';
      return;
    }
    if (this.resourceType === 'link' && !this.url.trim()) {
      this.errorMsg = 'URL is required for a link';
      return;
    }
    this.busy = true;
    this.errorMsg = '';
    try {
      const req: { name: string; url?: string; type: string } = {
        name,
        type: this.resourceType
      };
      if (this.url.trim()) req.url = this.url.trim();
      await createProjectResource(this.id, req);
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to add resource';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Add resource',
        scheme: this.scheme,
        left: this.CancelButton()
      })

      Scroll() {
        Column() {
          if (this.errorMsg) {
            MulticaText({
              value: this.errorMsg,
              scheme: this.scheme,
              size: 'sm',
              color: 'destructive'
            })
              .margin({ bottom: SPACE['3'] })
              .width('100%')
          }

          MulticaText({
            value: 'Name',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .width('100%')
          TextInput({ text: this.name, placeholder: 'Resource name' })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.name = value; })

          MulticaText({
            value: 'Type',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['4'] })
            .width('100%')
          Column() {
            ForEach(RESOURCE_TYPES, (t) => {
              PickerRow({
                label: t.label,
                selected: this.resourceType === t.value,
                scheme: this.scheme,
                onTap: (): void => { this.resourceType = t.value; }
              })
            })
          }
          .margin({ top: SPACE['1'] })
          .width('100%')

          MulticaText({
            value: 'URL',
            scheme: this.scheme,
            size: 'xs',
            weight: 'medium',
            color: 'mutedForeground'
          })
            .margin({ top: SPACE['4'] })
            .width('100%')
          TextInput({ text: this.url, placeholder: 'https://…' })
            .placeholderColor(String(THEME[this.scheme].mutedForeground))
            .fontColor(String(THEME[this.scheme].foreground))
            .backgroundColor(String(THEME[this.scheme].card))
            .borderRadius(RADIUS.md)
            .padding(SPACE['3'])
            .width('100%')
            .margin({ top: SPACE['1'] })
            .onChange((value: string) => { this.url = value; })

          MulticaButton({
            label: this.busy ? 'Adding…' : 'Add resource',
            scheme: this.scheme,
            variant: 'primary',
            disabled: this.busy || this.name.trim().length === 0,
            onTap: () => { void this.save(); }
          })
            .margin({ top: SPACE['6'] })
        }
        .width('100%')
        .padding(SPACE['4'])
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder CancelButton() {
    IconButton({
      glyph: '✕',
      scheme: this.scheme,
      accessibilityLabel: 'Cancel',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
