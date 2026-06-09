import router from '@ohos.router';
import { api } from '../data/api';
import { useQuery } from '../queries/cache';
import { Issue, Project } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { IssueRow } from '../components/issue/IssueRow';
import { ProjectRow } from '../components/project/ProjectRow';

@Entry
@Component
struct SearchPage {
  @State scheme: ColorScheme = 'light';
  @State tab: 'issues' | 'projects' | 'pins' = 'issues';
  @State query: string = '';
  @State debouncedQuery: string = '';
  @State projects: Project[] = [];
  @State pins: { id: string; label: string; sub: string }[] = [];
  private debounceHandle: ReturnType<typeof setTimeout> | null = null;
  private issuesQuery = useQuery<{ issues: Issue[]; total: number }>(
    ['search-issues'],
    () => Promise.resolve({ issues: [], total: 0 }),
    { enabled: false }
  );

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    const params = router.getParams() as Record<string, string> | undefined;
    const requested = params?.['tab'];
    if (requested === 'projects' || requested === 'pins') {
      this.tab = requested;
    }
    void this.loadPins();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private onQuery(value: string): void {
    this.query = value;
    if (this.debounceHandle) clearTimeout(this.debounceHandle);
    this.debounceHandle = setTimeout(() => {
      this.debouncedQuery = value.trim();
      void this.runSearch();
    }, 250);
  }

  private async runSearch(): Promise<void> {
    if (this.tab !== 'issues') return;
    if (!this.debouncedQuery) return;
    try {
      const res = await api.searchIssues(this.debouncedQuery);
      this.issuesQuery.refetch();
      // Direct render via issuesQuery state — the refetch will pick up
      // and re-bind to a fresh fetcher. For simplicity, we keep a local
      // copy and read it in build():
      this.issuesState = res.issues;
    } catch (err) {
      console.warn('[search] issues failed', err);
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

  private async searchProjects(): Promise<void> {
    if (!this.debouncedQuery) {
      this.projects = [];
      return;
    }
    try {
      const res = await api.searchProjects(this.debouncedQuery);
      this.projects = res.projects;
    } catch (err) {
      console.warn('[search] projects failed', err);
    }
  }

  @State issuesState: Issue[] = [];

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
          ForEach(this.issuesState, (issue: Issue) => {
            IssueRow({
              issue: issue,
              scheme: this.scheme,
              onPress: () => { router.pushUrl({ url: 'pages/IssueDetailPage', params: { id: issue.id } }); }
            })
          })
          if (this.issuesState.length === 0 && this.debouncedQuery.length > 0) {
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
          ForEach(this.projects, (project: Project) => {
            ProjectRow({
              project: project,
              scheme: this.scheme,
              onPress: () => { router.pushUrl({ url: 'pages/ProjectDetailPage', params: { id: project.id } }); }
            })
          })
          if (this.projects.length === 0 && this.debouncedQuery.length > 0) {
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
      onTap: () => { router.back(); }
    })
  }
}
