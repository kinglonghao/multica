import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { projectDetailKey } from '../queries/project';
import { useMemberListQuery } from '../queries/members';
import { updateProject } from '../mutations/project';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { PickerRow } from '../components/issue/PickerRow';
import { MemberWithUser, Project } from '../models/types';

/**
 * Project lead picker. Pushed from `ProjectDetailPage` when
 * the user taps the lead chip. Lists every workspace member;
 * selecting one fires the optimistic `updateProject` mutation
 * with the new `lead_id`. The lead's denormalised name /
 * avatar fields are cleared by the mutation; the server
 * response (re-applied via `mutateDetail.onSuccess`) refills
 * them on the next render.
 */
@ComponentV2
export struct ProjectLeadPickerPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local busy: boolean = false;
  @Local errorMsg: string = '';
  private members: ReturnType<typeof useMemberListQuery> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.members = useMemberListQuery(() => { this.version++; });
  }

  aboutToDisappear(): void {
    this.members?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private currentLeadId(): string {
    const key = projectDetailKey(workspaceStore.currentId, this.id);
    const project = queryClient.get<Project>(key)?.data;
    return project?.lead_id ?? '';
  }

  private async pick(leadId: string | null): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateProject(this.id, { lead_id: leadId ?? undefined });
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to update lead';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Lead',
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (this.errorMsg) {
        MulticaText({
          value: this.errorMsg,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
          .width('100%')
      }

      Scroll() {
        const cur = this.currentLeadId();
        Column() {
          PickerRow({
            label: 'No lead',
            selected: !cur,
            scheme: this.scheme,
            onTap: (): void => { void this.pick(null); }
          })
          if (this.members) {
            const state = this.members.getState();
            const list: MemberWithUser[] = state.data ?? [];
            ForEach(list, (m: MemberWithUser) => {
              PickerRow({
                label: m.user?.display_name ?? m.user?.email ?? 'Unknown',
                selected: cur === m.user_id,
                scheme: this.scheme,
                leadingIcon: this.MemberAvatar(m),
                onTap: (): void => { void this.pick(m.user_id); }
              })
            })
          }
        }
        .width('100%')
        .padding({ left: SPACE['2'], right: SPACE['2'], top: SPACE['2'], bottom: SPACE['4'] })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder MemberAvatar(m: MemberWithUser) {
    Avatar({
      name: m.user?.display_name ?? m.user?.email ?? '·',
      url: m.user?.avatar_url ?? '',
      size: 24,
      scheme: this.scheme
    })
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
