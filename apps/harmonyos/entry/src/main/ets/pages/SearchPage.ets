import { appNavigation, navParam } from '../data/navigation';
import { api } from '../data/api';
import { Issue, Project } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { IssueRow } from '../components/issue/IssueRow';
import { ProjectRow } from '../components/project/ProjectRow';

const DEBOUNCE_MS = 250;
const SEARCH_TABS: ReadonlyArray<'issues' | 'projects' | 'pins'> = ['issues', 'projects', 'pins'];

/** Local view-model for a pin row in the search pins tab. Named
 *  interface because ArkTS forbids inline object-literal types. */
interface PinRow {
  id: string;
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
  private debounceHandle: number | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.tab = this.initialTab;
    void this.loadPins();
  }

  private detectScheme(): ColorScheme {
    return 'light';
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
      return;
    }
    try {
      const res = await api.searchIssues(this.debouncedQuery);
      this.issueResults = res.issues;
    } catch (err) {
      console.warn('[search] issues failed', err);
    }
  }

  private async runProjectSearch(): Promise<void> {
    if (!this.debouncedQuery) {
      this.projectResults = [];
      return;
    }
    try {
      const res = await api.searchProjects(this.debouncedQuery);
      this.projectResults = res.projects;
    } catch (err) {
      console.warn('[search] projects failed', err);
    }
  }

  private async loadPins(): Promise<void> {
    try {
      const pins = await api.listPins();
      this.pins = pins.map((p): PinRow => this.toPinRow(p.id, p.type, p.item_id, p.created_at));
    } catch (err) {
      console.warn('[search] pins failed', err);
    }
  }

  private toPinRow(id: string, type: 'issue' | 'project' | 'doc', itemId: string, createdAt: string): PinRow {
    return {
      id,
      label: type === 'issue' ? `Issue ${itemId}` :
             type === 'project' ? `Project ${itemId}` : `Doc ${itemId}`,
      sub: `Pinned ${new Date(createdAt).toLocaleDateString()}`
    };
  }

  build() {
    Column() {
      Header({
        title: 'Search',
        scheme: this.scheme,
        left: this.BackButton()
      })

      Row() {
        this.Tab('issues', 'Issues')
        this.Tab('projects', 'Projects')
        this.Tab('pins', 'Pinned')
      }
      .width('100%')
      .padding(space('2'))
      .border({
        width: { bottom: 1 },
        color: String(themeTokens(this.scheme).border)
      })

      TextInput({ placeholder: 'Search…', text: this.query })
        .placeholderColor(String(themeTokens(this.scheme).mutedForeground))
        .fontColor(String(themeTokens(this.scheme).foreground))
        .backgroundColor(String(themeTokens(this.scheme).card))
        .borderRadius(RADIUS.md)
        .padding(space('3'))
        .width('100%')
        .margin({ top: space('3'), left: space('4'), right: space('4') })
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
        Column() {
          ForEach(this.pins, (pin: PinRow) => {
            Row() {
              MulticaText({
                value: pin.label,
                scheme: this.scheme,
                textSize: 'base',
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
            .padding(space('4'))
            .border({
              width: { bottom: 1 },
              color: String(themeTokens(this.scheme).border)
            })
          })
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
        .layoutWeight(1)
        .width('100%')
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
        weight: this.tab === name ? 'medium' : 'normal',
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

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }
}
