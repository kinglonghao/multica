/**
 * Destination builder for the app's single root `Navigation`. Maps
 * logical page names (passed via `appNavigation.pushName(name, param)`)
 * to the corresponding `@ComponentV2` page struct.
 *
 * Each branch reads the relevant `param` keys (cast through a
 * type-narrowing helper, NOT `as unknown as string`) and passes them
 * as `@Param` to the page component. The page itself never calls
 * `stack.getParamByName` — params arrive as proper props, which fixes
 * CRITICAL-7 (the v0.2 page always rendered blank because
 * `aboutToAppear` ran before the path was pushed).
 *
 * `WorkspaceLayout` is special — it has the bottom tab bar and hosts
 * the Inbox / My Issues / Chat / More tab pages as children. It is
 * NOT pushed via the path stack; it's the default landing page after
 * the user is authed. Index.ets mounts it directly inside the
 * Navigation root.
 */
import { LoginPage } from './LoginPage';
import { VerifyPage } from './VerifyPage';
import { SelectWorkspacePage } from './SelectWorkspacePage';
import { IssueDetailPage } from './IssueDetailPage';
import { ProjectDetailPage } from './ProjectDetailPage';
import { NewIssuePage } from './NewIssuePage';
import { SearchPage } from './SearchPage';
import { SwitchWorkspacePage } from './SwitchWorkspacePage';
import { ProfilePage } from './ProfilePage';
import { NotificationsPage } from './NotificationsPage';
import { AgentsPage } from './AgentsPage';
import { ChatDetailPage } from './ChatDetailPage';
import { IssueStatusPickerPage } from './IssueStatusPickerPage';
import { IssuePriorityPickerPage } from './IssuePriorityPickerPage';
import { IssueRunsPage } from './IssueRunsPage';
import { IssueEditPage } from './IssueEditPage';
import { IssueAssigneePickerPage } from './IssueAssigneePickerPage';
import { IssueProjectPickerPage } from './IssueProjectPickerPage';
import { ProjectEditPage } from './ProjectEditPage';
import { ProjectStatusPickerPage } from './ProjectStatusPickerPage';
import { ProjectPriorityPickerPage } from './ProjectPriorityPickerPage';
import { ProjectLeadPickerPage } from './ProjectLeadPickerPage';
import { AddProjectResourcePage } from './AddProjectResourcePage';

function readString(param: object | undefined, key: string, fallback: string): string {
  if (param === undefined) return fallback;
  const map = param as Record<string, string | number | boolean>;
  const v = map[key];
  return typeof v === 'string' ? v : fallback;
}

function readTab(param: object | undefined, fallback: 'issues' | 'projects' | 'pins'): 'issues' | 'projects' | 'pins' {
  const v = readString(param, 'tab', fallback);
  if (v === 'projects' || v === 'pins' || v === 'issues') return v;
  return fallback;
}

@Builder
export function PageDestinations(name: string, param: object): void {
  if (name === 'LoginPage') {
    LoginPage();
  } else if (name === 'VerifyPage') {
    VerifyPage({ initialEmail: readString(param, 'email', '') });
  } else if (name === 'SelectWorkspacePage') {
    SelectWorkspacePage();
  } else if (name === 'IssueDetailPage') {
    IssueDetailPage({ id: readString(param, 'id', '') });
  } else if (name === 'ProjectDetailPage') {
    ProjectDetailPage({ id: readString(param, 'id', '') });
  } else if (name === 'NewIssuePage') {
    NewIssuePage();
  } else if (name === 'SearchPage') {
    SearchPage({ initialTab: readTab(param, 'issues') });
  } else if (name === 'SwitchWorkspacePage') {
    SwitchWorkspacePage();
  } else if (name === 'ProfilePage') {
    ProfilePage();
  } else if (name === 'NotificationsPage') {
    NotificationsPage();
  } else if (name === 'AgentsPage') {
    AgentsPage();
  } else if (name === 'ChatDetailPage') {
    ChatDetailPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssueStatusPickerPage') {
    IssueStatusPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssuePriorityPickerPage') {
    IssuePriorityPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssueRunsPage') {
    IssueRunsPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssueEditPage') {
    IssueEditPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssueAssigneePickerPage') {
    IssueAssigneePickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'IssueProjectPickerPage') {
    IssueProjectPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'ProjectEditPage') {
    ProjectEditPage({ id: readString(param, 'id', '') });
  } else if (name === 'ProjectStatusPickerPage') {
    ProjectStatusPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'ProjectPriorityPickerPage') {
    ProjectPriorityPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'ProjectLeadPickerPage') {
    ProjectLeadPickerPage({ id: readString(param, 'id', '') });
  } else if (name === 'AddProjectResourcePage') {
    AddProjectResourcePage({ id: readString(param, 'id', '') });
  }
}
