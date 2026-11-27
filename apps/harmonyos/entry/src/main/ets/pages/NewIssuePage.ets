import hilog from '@ohos.hilog';
import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { CreateIssueRequest, IssueStatus, IssuePriority, MemberWithUser, Project, Agent, IssueAssigneeType } from '../models/types';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { MulticaButton } from '../components/ui/Button';

const NEW_ISSUE_DEBUG_DOMAIN = 0xFF19;
const NEW_ISSUE_DEBUG_TAG = 'NewIssuePage';


@ComponentV2
export struct NewIssuePage {
  @Local scheme: ColorScheme = 'light';
  @Local title: string = '';
  @Local description: string = '';
  @Local status: IssueStatus = 'todo';
  @Local priority: IssuePriority = 'none';
  @Local assigneeId: string | null = null;
  @Local assigneeType: IssueAssigneeType = null;
  @Local assigneeName: string = 'No assignee';
  @Local projectId: string | null = null;
  @Local projectName: string = 'No project';
  @Local menuVisible: boolean = false;
  @Local menuKind: 'status' | 'priority' | 'assignee' | 'project' | '' = '';
  @Local pressedPicker: string = '';
  @Local saving: boolean = false;
  @Local errorMessage: string = '';
  private members: MemberWithUser[] = [];
  private agents: Agent[] = [];
  private projects: Project[] = [];

  // #region debug-point issue-create-crash
  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(NEW_ISSUE_DEBUG_DOMAIN, NEW_ISSUE_DEBUG_TAG,
      `stage=${stage} titleLen=${this.title.length} issueStatus=${this.status} priority=${this.priority} ${extra}`);
  }

  private debugError(stage: string, err: Object | null = null): void {
    const message = err instanceof Error ? err.message : `${err ?? 'unknown'}`;
    hilog.error(NEW_ISSUE_DEBUG_DOMAIN, NEW_ISSUE_DEBUG_TAG,
      `stage=${stage} error=${message}`);
  }
  // #endregion

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.debugInfo('aboutToAppear');
    void this.loadOptions();
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }


  private async loadOptions(): Promise<void> {
    const wsId = workspaceStore.currentId;
    if (!wsId) return;
    try {
      const members = await api.listMembers(wsId);
      const agents = await api.listAgents();
      const projectsResponse = await api.listProjects();
      this.members = members;
      this.agents = agents;
      this.projects = projectsResponse.projects;
    } catch (err) {
      this.debugError('loadOptions:catch', err as Object);
    }
  }

  private memberDisplayName(member: MemberWithUser): string {
    return member.user?.display_name ?? member.user?.email ?? member.name ?? member.email ?? 'Unknown member';
  }

  private agentDisplayName(agent: Agent): string {
    return agent.name?.trim() || 'Unknown agent';
  }

  private openMenu(kind: 'status' | 'priority' | 'assignee' | 'project'): void {
    this.menuKind = kind;
    this.menuVisible = true;
  }

  private closeMenu(): void {
    this.menuVisible = false;
    this.menuKind = '';
  }

  private statusOptions(): IssueStatus[] {
    return ['backlog', 'todo', 'in_progress', 'in_review', 'done', 'cancelled'];
  }

  private priorityOptions(): IssuePriority[] {
    return ['none', 'low', 'medium', 'high', 'urgent'];
  }

  private selectStatus(status: IssueStatus): void {
    this.status = status;
    this.closeMenu();
  }

  private selectPriority(priority: IssuePriority): void {
    this.priority = priority;
    this.closeMenu();
  }

  private clearAssignee(): void {
    this.assigneeId = null;
    this.assigneeType = null;
    this.assigneeName = 'No assignee';
    this.closeMenu();
  }

  private selectAssignee(member: MemberWithUser): void {
    this.assigneeId = member.user_id;
    this.assigneeType = 'member';
    this.assigneeName = this.memberDisplayName(member);
    this.closeMenu();
  }

  private selectAgent(agent: Agent): void {
    this.assigneeId = agent.id;
    this.assigneeType = 'agent';
    this.assigneeName = this.agentDisplayName(agent);
    this.closeMenu();
  }

  private clearProject(): void {
    this.projectId = null;
    this.projectName = 'No project';
    this.closeMenu();
  }

  private selectProject(project: Project): void {
    this.projectId = project.id;
    this.projectName = project.name;
    this.closeMenu();
  }


  private async submit(): Promise<void> {
    this.debugInfo('submit:start', `descriptionLen=${this.description.length}`);
    if (this.title.trim().length === 0) {
      this.errorMessage = 'Title is required';
      this.debugInfo('submit:blocked-empty-title');
      return;
    }
    this.saving = true;
    this.errorMessage = '';
    try {
      const req: CreateIssueRequest = {
        title: this.title.trim(),
        description: this.description.trim() || undefined,
        status: this.status,
        priority: this.priority
      };
      if (this.assigneeId && this.assigneeType) {
        req.assignee_id = this.assigneeId;
        req.assignee_type = this.assigneeType;
      }
      if (this.projectId) {
        req.project_id = this.projectId;
      }
      this.debugInfo('submit:request-ready', `trimmedTitleLen=${req.title.length}`);
      const issue = await api.createIssue(req);
      this.debugInfo('submit:created', `issueId=${issue.id}`);
      this.invalidateIssueLists();
      this.debugInfo('submit:invalidate-done', `workspace=${workspaceStore.currentId ?? 'null'}`);
      appNavigation.pushName('IssueDetailPage', navParam('id', issue.id));
      this.debugInfo('submit:navigate', `issueId=${issue.id}`);
    } catch (err) {
      this.debugError('submit:catch', err as Object);
      this.errorMessage = err instanceof Error ? err.message : 'Failed to create issue';
    } finally {
      this.saving = false;
      this.debugInfo('submit:finally', `error=${this.errorMessage || 'none'}`);
    }
  }

  private invalidateIssueLists(): void {
    queryClient.invalidatePrefix(['issues', workspaceStore.currentId]);
  }

  private pickerValue(label: string): string {
    if (label === 'Status') return statusLabel(this.status);
    if (label === 'Priority') return priorityLabel(this.priority);
    if (label === 'Assignee') return this.assigneeName;
    if (label === 'Project') return this.projectName;
    return '';
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        Scroll() {
          Column({ space: space('4') }) {
            MulticaText({
              value: 'New issue',
              scheme: this.scheme,
              textSize: 'xl',
              weight: 'bold',
              color: 'foreground'
            })
              .width('100%')

            TextInput({ placeholder: 'Issue title', text: this.title })
              .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
              .fontColor(String(themeTokens(this.scheme).foreground))
              .backgroundColor('transparent')
              .fontSize(28)
              .fontWeight(FontWeight.Medium)
              .padding({ top: space('2'), bottom: space('2') })
              .width('100%')
              .onChange((value: string) => {
                this.title = value;
                this.errorMessage = '';
              })

            TextArea({ placeholder: 'Add description...', text: this.description })
              .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
              .fontColor(String(themeTokens(this.scheme).foreground))
              .backgroundColor('transparent')
              .fontSize(16)
              .padding({ top: 0, bottom: 0 })
              .width('100%')
              .height(120)
              .onChange((value: string) => {
                this.description = value;
              })

            Column({ space: space('3') }) {
              this.PickerRow('Status', '◌')
              this.PickerRow('Priority', '↑')
              this.PickerRow('Assignee', '◉')
              this.PickerRow('Project', '▣')
            }
            .margin({ top: space('2') })

            if (this.errorMessage) {
              MulticaText({
                value: this.errorMessage,
                scheme: this.scheme,
                textSize: 'sm',
                color: 'destructive'
              })
            }

            MulticaButton({
              label: this.saving ? 'Saving…' : 'Create',
              scheme: this.scheme,
              variant: 'primary',
              fullWidth: true,
              disabled: this.saving || this.title.trim().length === 0,
              onTap: () => { void this.submit(); }
            })
              .margin({ top: space('2') })
          }
          .padding({ left: space('4'), right: space('4'), top: space('6'), bottom: space('6') })
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(themeTokens(this.scheme).background))

      if (this.menuVisible) {
        this.MenuSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder PickerRow(label: string, glyph: string) {
    Button() {
      Row() {
        MulticaText({
          value: glyph,
          scheme: this.scheme,
          textSize: 'sm',
          color: 'mutedForeground'
        })
          .margin({ right: space('2') })
        MulticaText({
          value: label,
          scheme: this.scheme,
          textSize: 'base',
          weight: 'medium',
          color: 'foreground'
        })
        Blank()
        MulticaText({
          value: this.pickerValue(label),
          scheme: this.scheme,
          textSize: 'base',
          color: 'mutedForeground'
        })
        MulticaText({
          value: ' ›',
          scheme: this.scheme,
          textSize: 'base',
          color: 'mutedForeground'
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
    }
    .type(ButtonType.Normal)
    .stateEffect(false)
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
    .backgroundColor(this.pressedPicker === label ? '#2A2A2E' : String(themeTokens(this.scheme).card))
    .borderRadius(RADIUS.md)
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.pressedPicker = label;
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        this.pressedPicker = '';
      }
    })
    .onClick(() => {
      if (label === 'Status') {
        this.openMenu('status');
      } else if (label === 'Priority') {
        this.openMenu('priority');
      } else if (label === 'Assignee') {
        this.openMenu('assignee');
      } else if (label === 'Project') {
        this.openMenu('project');
      }
    })
  }

  @Builder MenuSheet() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#00000055')
        .onClick(() => { this.closeMenu(); })

      Column() {
        Scroll() {
          Column() {
            if (this.menuKind === 'status') {
              ForEach(this.statusOptions(), (status: IssueStatus) => {
                this.MenuAction(statusLabel(status), false, () => { this.selectStatus(status); })
              })
            } else if (this.menuKind === 'priority') {
              ForEach(this.priorityOptions(), (priority: IssuePriority) => {
                this.MenuAction(priorityLabel(priority), false, () => { this.selectPriority(priority); })
              })
            } else if (this.menuKind === 'assignee') {
              this.MenuAction('No assignee', false, () => { this.clearAssignee(); })
              ForEach(this.members, (member: MemberWithUser) => {
                this.MenuAction(this.memberDisplayName(member), false, () => { this.selectAssignee(member); })
              })
              ForEach(this.agents, (agent: Agent) => {
                this.MenuAction(`${this.agentDisplayName(agent)} · Agent`, false, () => { this.selectAgent(agent); })
              })
            } else if (this.menuKind === 'project') {
              this.MenuAction('No project', false, () => { this.clearProject(); })
              ForEach(this.projects, (project: Project) => {
                this.MenuAction(project.name, false, () => { this.selectProject(project); })
              })
            }

            this.MenuAction('Cancel', false, () => { this.closeMenu(); })
          }
          .width('100%')
        }
        .width('100%')
        .scrollBar(BarState.Off)
        .constraintSize({ maxHeight: '55%' })
      }
      .width('100%')
      .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
      .backgroundColor(String(themeTokens(this.scheme).background))
      .borderRadius(18)
      .margin({ left: space('3'), right: space('3'), bottom: space('3') })
    }
    .width('100%')
    .height('100%')
  }

  @Builder MenuSectionLabel(label: string) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'xs',
        weight: 'medium',
        color: 'mutedForeground'
      })
    }
    .width('100%')
    .padding({ left: space('2'), right: space('2'), top: space('3'), bottom: space('1') })
  }

  @Builder MenuAction(label: string, destructive: boolean, onTap: () => void) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'base',
        weight: 'medium',
        color: destructive ? 'destructive' : 'foreground',
        textAlign: 'center'
      })
    }
    .width('100%')
    .padding({ left: space('4'), right: space('4'), top: space('4'), bottom: space('4') })
    .backgroundColor(String(themeTokens(this.scheme).background))
    .borderRadius(14)
    .margin({ top: space('2') })
    .justifyContent(FlexAlign.Center)
    .onClick(() => { onTap(); })
  }
}
