import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { Issue, Project } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { IssueRow } from '../components/issue/IssueRow';
import { ProjectRow } from '../components/project/ProjectRow';

const DEBOUNCE_MS = 250;
const SEARCH_TABS: ReadonlyArray<'issues' | 'projects' | 'pins'> = ['issues', 'projects', 'pins'];

@ComponentV2
export struct SearchPage {
  @Param initialTab: 'issues' | 'projects' | 'pins' = 'issues';
  @Local scheme: ColorScheme = 'light';
  @Local tab: 'issues' | 'projects' | 'pins' = 'issues';
  @Local query: string = '';
  @Local debouncedQuery: string = '';
  @Local issueResults: Issue[] = [];
  @Local projectResults: Project[] = [];
  @Local pins: { id: string; label: string; sub: string }[] = [];
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
      this.pins = pins.map(p => ({
        id: p.id,
        label: p.type === 'issue' ? `Issue ${p.item_id}` :
               p.type === 'project' ? `Project ${p.item_id}` : `Doc ${p.item_id}`,
        sub: `Pinned ${new Date(p.created_at).toLocaleDateString()}`
      }));
    } catch (err) {
      console.warn('[search] pins failed', err);
    }
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
      .padding(SPACE['2'])
      .border({
        width: { bottom: 1 },
        color: String(THEME[this.scheme].border)
      })

      TextInput({ placeholder: 'Search…', text: this.query })
        .placeholderColor(String(THEME[this.scheme].mutedForeground))
        .fontColor(String(THEME[this.scheme].foreground))
        .backgroundColor(String(THEME[this.scheme].card))
        .borderRadius(RADIUS.md)
        .padding(SPACE['3'])
        .width('100%')
        .margin({ top: SPACE['3'], left: SPACE['4'], right: SPACE['4'] })
        .onChange((value: string) => { this.onQuery(value); })

      if (this.tab === 'issues') {
        Column() {
          ForEach(this.issueResults, (issue: Issue) => {
            IssueRow({
              issue: issue,
              scheme: this.scheme,
              onPress: () => { appNavigation.pushName('IssueDetailPage', { id: issue.id }); }
            })
          })
          if (this.issueResults.length === 0 && this.debouncedQuery.length > 0) {
            MulticaText({
              value: 'No issues match your search',
              scheme: this.scheme,
              size: 'sm',
              color: 'mutedForeground',
              textAlign: TextAlign.Center
            })
              .padding(SPACE['6'])
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
              onPress: () => { appNavigation.pushName('ProjectDetailPage', { id: project.id }); }
            })
          })
          if (this.projectResults.length === 0 && this.debouncedQuery.length > 0) {
            MulticaText({
              value: 'No projects match your search',
              scheme: this.scheme,
              size: 'sm',
              color: 'mutedForeground',
              textAlign: TextAlign.Center
            })
              .padding(SPACE['6'])
          }
        }
        .layoutWeight(1)
        .width('100%')
      } else {
        Column() {
          ForEach(this.pins, (pin) => {
            Row() {
              MulticaText({
                value: pin.label,
                scheme: this.scheme,
                size: 'base',
                color: 'foreground'
              })
              Blank()
              MulticaText({
                value: pin.sub,
                scheme: this.scheme,
                size: 'xs',
                color: 'mutedForeground'
              })
            }
            .width('100%')
            .padding(SPACE['4'])
            .border({
              width: { bottom: 1 },
              color: String(THEME[this.scheme].border)
            })
          })
          if (this.pins.length === 0) {
            MulticaText({
              value: 'No pinned items yet',
              scheme: this.scheme,
              size: 'sm',
              color: 'mutedForeground',
              textAlign: TextAlign.Center
            })
              .padding(SPACE['6'])
          }
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder Tab(name: 'issues' | 'projects' | 'pins', label: string) {
    Row() {
      MulticaText({
        value: label,
        scheme: this.scheme,
        size: 'sm',
        weight: this.tab === name ? 'medium' : 'normal',
        color: this.tab === name ? 'foreground' : 'mutedForeground'
      })
    }
    .layoutWeight(1)
    .padding({ top: SPACE['2'], bottom: SPACE['2'] })
    .backgroundColor(this.tab === name ? String(THEME[this.scheme].card) : 'transparent')
    .borderRadius(RADIUS.md)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
