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
import { NavParam } from '../data/navigation';

function readString(param: object | undefined, _key: string, fallback: string): string {
  if (param === undefined) return fallback;
  const v = (param as NavParam).value;
  return typeof v === 'string' ? v : fallback;
}

function readTab(param: object | undefined, fallback: 'issues' | 'projects' | 'pins'): 'issues' | 'projects' | 'pins' {
  if (param === undefined) return fallback;
  const v = (param as NavParam).value;
  if (v === 'projects' || v === 'pins' || v === 'issues') return v;
  return fallback;
}

/**
 * Each branch wraps the page in a `NavDestination()`. The Navigation
 * component's `navDestination` builder contract (see HarmonyOS docs
 * for the `navDestination` attribute) requires a single root node —
 * either a bare `NavDestination` or a custom component layer outside
 * it. Crucially, that outer custom-component layer must have NO
 * attributes or events set, otherwise "only blank components are
 * displayed". Calling the page components directly (e.g.
 * `LoginPage()`) tripped that rule and was the root cause of the
 * white-screen on first launch: `aboutToAppear` ran, the framework
 * rendered the NavDestination chrome (so the back-arrow showed up),
 * but the page body — which uses chains of `.padding`, `.margin`,
 * `.backgroundColor`, etc. — was treated as invalid and replaced by
 * an empty node.
 *
 * Wrapping each call in `NavDestination() { Page() }` keeps the
 * page's @ComponentV2 struct unchanged (and so its `aboutToAppear`
 * lifecycle, @Local state, and param reading via
 * `appNavigation.readString`) intact, while satisfying the builder
 * contract.
 */
@Builder
export function PageDestinations(name: string, param: object): void {
  if (name === 'LoginPage') {
    NavDestination() {
      LoginPage();
    }
  } else if (name === 'VerifyPage') {
    NavDestination() {
      VerifyPage();
    }
  } else if (name === 'SelectWorkspacePage') {
    NavDestination() {
      SelectWorkspacePage();
    }
  } else if (name === 'IssueDetailPage') {
    NavDestination() {
      IssueDetailPage({ issueId: readString(param, 'id', '') });
    }
  } else if (name === 'ProjectDetailPage') {
    NavDestination() {
      ProjectDetailPage({ projectId: readString(param, 'id', '') });
    }
  } else if (name === 'NewIssuePage') {
    NavDestination() {
      NewIssuePage();
    }
  } else if (name === 'SearchPage') {
    NavDestination() {
      SearchPage({ initialTab: readTab(param, 'issues') });
    }
  } else if (name === 'SwitchWorkspacePage') {
    NavDestination() {
      SwitchWorkspacePage();
    }
  } else if (name === 'ProfilePage') {
    NavDestination() {
      ProfilePage();
    }
  } else if (name === 'NotificationsPage') {
    NavDestination() {
      NotificationsPage();
    }
  } else if (name === 'AgentsPage') {
    NavDestination() {
      AgentsPage();
    }
  } else if (name === 'ChatDetailPage') {
    NavDestination() {
      ChatDetailPage({ chatId: readString(param, 'id', '') });
    }
  }
}
