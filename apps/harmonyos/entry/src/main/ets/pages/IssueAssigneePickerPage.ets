import { appNavigation } from '../data/navigation';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { issueDetailKey } from '../queries/issue';
import { useMemberListQuery } from '../queries/members';
import { useAgentListQuery } from '../queries/agents';
import { updateIssue } from '../mutations/issue';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { PickerRow } from '../components/issue/PickerRow';
import { Agent, Issue, MemberWithUser } from '../models/types';

/**
 * Issue assignee picker. Lets the user assign the issue to a
 * workspace member OR an agent. Mirrors the iOS formSheet
 * pattern — the page is pushed on the navigation stack, reads
 * the current assignee from the cache, and on selection calls
 * the optimistic `updateIssue` mutation with the new
 * `assignee_id` / `assignee_type` pair.
 *
 * Why a combined picker (not a member-only one with a separate
 * agent sheet): the iOS app does the same — a single page with
 * two sections ("Members" / "Agents") and a "Unassign" row at
 * the top. Adding more screens would just be more taps for the
 * common "give it to a person" flow.
 */
@ComponentV2
export struct IssueAssigneePickerPage {
  @Param id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local busy: boolean = false;
  @Local errorMsg: string = '';
  private members: ReturnType<typeof useMemberListQuery> | null = null;
  private agents: ReturnType<typeof useAgentListQuery> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.members = useMemberListQuery(() => { this.version++; });
    this.agents = useAgentListQuery(() => { this.version++; });
  }

  aboutToDisappear(): void {
    this.members?.unsubscribe();
    this.agents?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private currentAssignee(): { id: string; type: 'member' | 'agent' | null } {
    const key = issueDetailKey(workspaceStore.currentId, this.id);
    const issue = queryClient.get<Issue>(key)?.data;
    if (!issue) return { id: '', type: null };
    return {
      id: issue.assignee_id ?? '',
      type: (issue.assignee_type as 'member' | 'agent' | null) ?? null
    };
  }

  private async pick(assignee: { id: string | null; type: 'member' | 'agent' | null }): Promise<void> {
    if (this.busy) return;
    this.busy = true;
    this.errorMsg = '';
    try {
      await updateIssue(this.id, {
        assignee_id: assignee.id,
        assignee_type: assignee.type
      });
      appNavigation.pop();
    } catch (err) {
      this.errorMsg = err instanceof Error ? err.message : 'Failed to update assignee';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Assignee',
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
        const cur = this.currentAssignee();
        Column() {
          PickerRow({
            label: 'Unassigned',
            selected: !cur.id,
            scheme: this.scheme,
            onTap: (): void => { void this.pick({ id: null, type: null }); }
          })

          this.SectionHeader('Members')
          if (this.members) {
            const mState = this.members.getState();
            const list: MemberWithUser[] = mState.data ?? [];
            ForEach(list, (m: MemberWithUser) => {
              PickerRow({
                label: m.user?.display_name ?? m.user?.email ?? 'Unknown',
                selected: cur.type === 'member' && cur.id === m.user_id,
                scheme: this.scheme,
                leadingIcon: this.MemberAvatar(m),
                onTap: (): void => { void this.pick({ id: m.user_id, type: 'member' }); }
              })
            })
          }

          this.SectionHeader('Agents')
          if (this.agents) {
            const aState = this.agents.getState();
            const list: Agent[] = aState.data ?? [];
            ForEach(list, (a: Agent) => {
              PickerRow({
                label: a.name,
                selected: cur.type === 'agent' && cur.id === a.id,
                scheme: this.scheme,
                leadingIcon: this.AgentAvatar(a),
                onTap: (): void => { void this.pick({ id: a.id, type: 'agent' }); }
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

  @Builder SectionHeader(label: string) {
    MulticaText({
      value: label,
      scheme: this.scheme,
      size: 'xs',
      weight: 'semibold',
      color: 'mutedForeground'
    })
      .padding({ left: SPACE['4'], top: SPACE['4'], bottom: SPACE['2'] })
      .width('100%')
  }

  @Builder MemberAvatar(m: MemberWithUser) {
    Avatar({
      name: m.user?.display_name ?? m.user?.email ?? '·',
      url: m.user?.avatar_url ?? '',
      size: 24,
      scheme: this.scheme
    })
  }

  @Builder AgentAvatar(a: Agent) {
    Avatar({
      name: a.name,
      url: a.avatar_url ?? '',
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
