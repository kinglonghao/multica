import hilog from '@ohos.hilog';
import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { Issue, Project, PinnedItem } from '../models/types';
import { workspaceStore } from '../data/workspace';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { IssueRow } from '../components/issue/IssueRow';
import { ProjectRow } from '../components/project/ProjectRow';

const DEBOUNCE_MS = 250;
const SEARCH_TABS: ReadonlyArray<'issues' | 'projects' | 'pins'> = ['issues', 'projects', 'pins'];
const SEARCH_DEBUG_DOMAIN = 0xFF14;
const SEARCH_DEBUG_TAG = 'SearchPage';

/** Local view-model for a pin row in the search pins tab. Named
 *  interface because ArkTS forbids inline object-literal types. */
interface PinRow {
  id: string;
  itemType: 'issue' | 'project' | 'doc';
  itemId: string;
  label: string;
  sub: string;
}

@ComponentV2
export struct SearchPage {
  @Param initialTab: 'issues' | 'projects' | 'pins' = 'issues';
  @Local scheme: ColorScheme = 'light';
  @Local tab: 'issues' | 'projects' | 'pins' = 'issues';
  @Local query: string = '';
  @Local debouncedQuery: string = '';
  @Local issueResults: Issue[] = [];
  @Local projectResults: Project[] = [];
  @Local pins: PinRow[] = [];
  @Local pinsLoading: boolean = false;
  @Local pinsError: string = '';
  private debounceHandle: number | null = null;

  // #region debug-point B:search-page-entry
  private debugInfo(stage: string, extra: string = ''): void {
    hilog.info(SEARCH_DEBUG_DOMAIN, SEARCH_DEBUG_TAG,
      `stage=${stage} initialTab=${this.initialTab} tab=${this.tab} workspaceId=${workspaceStore.currentId ?? 'null'} workspaceSlug=${workspaceStore.currentSlug ?? 'null'} ${extra}`);
  }

  private debugError(stage: string, err: Object | null = null): void {
    const message = err instanceof Error ? err.message : `${err ?? 'unknown'}`;
    hilog.error(SEARCH_DEBUG_DOMAIN, SEARCH_DEBUG_TAG,
      `stage=${stage} initialTab=${this.initialTab} tab=${this.tab} error=${message}`);
  }
  // #endregion

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.tab = this.initialTab;
    this.debugInfo('aboutToAppear');
    void this.loadPins();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private onQuery(value: string): void {
    this.query = value;
    if (this.debounceHandle !== null) clearTimeout(this.debounceHandle);
    this.debounceHandle = setTimeout(() => {
      this.debouncedQuery = value.trim();
      if (this.tab === 'issues') {
        void this.runIssueSearch();
      } else if (this.tab === 'projects') {
        void this.runProjectSearch();
      }
    }, DEBOUNCE_MS);
  }

  private async runIssueSearch(): Promise<void> {
    if (!this.debouncedQuery) {
      this.issueResults = [];
      this.debugInfo('runIssueSearch:skip-empty-query');
      return;
    }
    try {
      this.debugInfo('runIssueSearch:start', `query=${this.debouncedQuery}`);
      const res = await api.searchIssues(this.debouncedQuery);
      this.issueResults = res.issues;
      this.debugInfo('runIssueSearch:success', `count=${res.issues.length}`);
    } catch (err) {
      this.debugError('runIssueSearch:error', err as Object);
      console.warn('[search] issues failed', err);
    }
  }

  private async runProjectSearch(): Promise<void> {
    if (!this.debouncedQuery) {
      this.projectResults = [];
      this.debugInfo('runProjectSearch:skip-empty-query');
      return;
    }
    try {
      this.debugInfo('runProjectSearch:start', `query=${this.debouncedQuery}`);
      const res = await api.searchProjects(this.debouncedQuery);
      this.projectResults = res.projects;
      this.debugInfo('runProjectSearch:success', `count=${res.projects.length}`);
    } catch (err) {
      this.debugError('runProjectSearch:error', err as Object);
      console.warn('[search] projects failed', err);
    }
  }

  private async loadPins(): Promise<void> {
    this.pinsLoading = true;
    this.pinsError = '';
    this.debugInfo('loadPins:start');
    try {
      const pins = await api.listPins();
      this.pins = pins.map((p: PinnedItem): PinRow => this.toPinRow(p));
      this.debugInfo('loadPins:success', `count=${pins.length}`);
    } catch (err) {
      this.pins = [];
      this.pinsError = err instanceof Error ? err.message : 'Failed to load pinned items';
      this.debugError('loadPins:error', err as Object);
      console.warn('[search] pins failed', err);
    } finally {
      this.pinsLoading = false;
      this.debugInfo('loadPins:finally', `pinsLoading=${this.pinsLoading} pins=${this.pins.length} pinsError=${this.pinsError || 'none'}`);
    }
  }

  private toPinRow(pin: PinnedItem): PinRow {
    return {
      id: pin.id,
      itemType: pin.type,
      itemId: pin.item_id,
      label: pin.type === 'issue' ? `Issue ${pin.item_id}` :
             pin.type === 'project' ? `Project ${pin.item_id}` : `Doc ${pin.item_id}`,
      sub: `Pinned ${new Date(pin.created_at).toLocaleDateString()}`
    };
  }

  build() {
    Column() {
      Row() {
        this.Tab('issues', 'Issues')
        this.Tab('projects', 'Projects')
        this.Tab('pins', 'Pinned')
      }
      .width('100%')
      .padding({ left: space('3'), right: space('3'), top: space('3') })

      TextInput({ placeholder: 'Search...', text: this.query })
        .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
        .fontColor(String(themeTokens(this.scheme).foreground))
        .backgroundColor(String(themeTokens(this.scheme).background))
        .borderRadius(RADIUS.md)
        .padding({ left: space('3'), right: space('3'), top: space('2.5'), bottom: space('2.5') })
        .width('100%')
        .margin({ top: space('3'), left: space('3'), right: space('3') })
        .onChange((value: string) => { this.onQuery(value); })

      if (this.tab === 'issues') {
        Column() {
          ForEach(this.issueResults, (issue: Issue) => {
            IssueRow({
              issue: issue,
              scheme: this.scheme,
              onPress: () => { appNavigation.pushName('IssueDetailPage', navParam('id', issue.id)); }
            })
          })
          if (this.issueResults.length === 0 && this.debouncedQuery.length > 0) {
            MulticaText({
              value: 'No issues match your search',
              scheme: this.scheme,
              textSize: 'sm',
              color: 'mutedForeground',
              textAlign: 'center'
            })
              .padding(space('6'))
          }
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this.tab === 'projects') {
        Column() {
          ForEach(this.projectResults, (project: Project) => {
            ProjectRow({
              project: project,
              scheme: this.scheme,
              onPress: () => { appNavigation.pushName('ProjectDetailPage', navParam('id', project.id)); }
            })
          })
          if (this.projectResults.length === 0 && this.debouncedQuery.length > 0) {
            MulticaText({
              value: 'No projects match your search',
              scheme: this.scheme,
              textSize: 'sm',
              color: 'mutedForeground',
              textAlign: 'center'
            })
              .padding(space('6'))
          }
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        if (this.pinsLoading) {
          Column() {
            MulticaText({
              value: 'Loading pinned items…',
              scheme: this.scheme,
              textSize: 'sm',
              color: 'mutedForeground',
              textAlign: 'center'
            })
              .padding(space('6'))
          }
          .layoutWeight(1)
          .width('100%')
        } else if (this.pinsError) {
          Column() {
            MulticaText({
              value: `Failed to load pinned items: ${this.pinsError}`,
              scheme: this.scheme,
              textSize: 'sm',
              color: 'destructive',
              textAlign: 'center'
            })
              .padding(space('6'))
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          List({ space: 0 }) {
            ForEach(this.pins, (pin: PinRow) => {
              ListItem() {
                Row() {
                  MulticaText({
                    value: pin.label,
                    scheme: this.scheme,
                    textSize: 'sm',
                    color: 'foreground'
                  })
                  Blank()
                  MulticaText({
                    value: pin.sub,
                    scheme: this.scheme,
                    textSize: 'xs',
                    color: 'mutedForeground'
                  })
                }
                .width('100%')
                .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('3') })
                .onClick(() => {
                  if (pin.itemType === 'issue') {
                    appNavigation.pushName('IssueDetailPage', navParam('id', pin.itemId));
                    return;
                  }
                  if (pin.itemType === 'project') {
                    appNavigation.pushName('ProjectDetailPage', navParam('id', pin.itemId));
                  }
                })
              }
            })
          }
          .layoutWeight(1)
          .width('100%')
          .padding({ left: space('3'), right: space('3'), top: space('3') })
          .divider(null)
          .backgroundColor(String(themeTokens(this.scheme).background))

          if (this.pins.length === 0) {
            MulticaText({
              value: 'No pinned items yet',
              scheme: this.scheme,
              textSize: 'sm',
              color: 'mutedForeground',
              textAlign: 'center'
            })
              .padding(space('6'))
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder Tab(name: 'issues' | 'projects' | 'pins', label: string) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        textSize: 'sm',
        weight: this.tab === name ? 'semibold' : 'normal',
        color: this.tab === name ? 'foreground' : 'mutedForeground'
      })
    }
    .layoutWeight(1)
    .padding({ top: space('2'), bottom: space('2') })
    .backgroundColor(this.tab === name ? String(themeTokens(this.scheme).card) : 'transparent')
    .borderRadius(RADIUS.md)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { this.tab = name; })
  }
}
