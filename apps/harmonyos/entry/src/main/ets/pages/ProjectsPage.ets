import { appNavigation, navParam } from '../data/navigation';
import { useProjectListQuery } from '../queries/project';
import { QueryHandle, queryClient } from '../queries/cache';
import { useProjectRealtime } from '../realtime/realtime-hooks';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { ProjectRow } from '../components/project/ProjectRow';
import { ListProjectsResponse, Project } from '../models/types';

@ComponentV2
export struct ProjectsPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local _isLoading: boolean = true;
  @Local _data: ListProjectsResponse | undefined = undefined;
  @Local _error: Error | null = null;
  private query: QueryHandle<ListProjectsResponse> | null = null;
  private globalUnsub?: () => void;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useProjectListQuery(() => {
      this.version++;
      this.syncFromCache();
    });
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    this.wsUnsub = useProjectRealtime(null);
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.globalUnsub?.();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private syncFromCache(): void {
    if (!this.query) return;
    const s = this.query.getState();
    this._isLoading = s.isLoading;
    this._data = s.data as ListProjectsResponse | undefined;
    this._error = s.error;
  }

  private projectItems(): Project[] {
    return this._data?.projects ?? [];
  }

  build() {
    Column() {
      Header({ title: 'Projects', scheme: this.scheme })

      if (this._isLoading) {
        Column() {
          ForEach([1, 2, 3], () => {
            Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 72, radius: RADIUS.lg })
              .margin({ left: space('3'), right: space('3'), top: space('2') })
          })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this._error) {
        Column() {
          MulticaText({
            value: '加载项目失败',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'semibold',
            textAlign: 'center'
          })
          MulticaText({
            value: this._error.message,
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground',
            textAlign: 'center'
          })
            .margin({ top: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else if (this.projectItems().length === 0) {
        Column() {
          MulticaText({
            value: '还没有项目',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'semibold',
            textAlign: 'center'
          })
          MulticaText({
            value: '创建项目后会显示在这里。',
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground',
            textAlign: 'center'
          })
            .margin({ top: space('2') })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.projectItems(), (project: Project) => {
            ListItem() {
              ProjectRow({
                project: project,
                scheme: this.scheme,
                onPress: () => { appNavigation.pushName('ProjectDetailPage', navParam('id', project.id)); }
              })
            }
            .padding({ left: space('3'), right: space('3'), top: 5, bottom: 5 })
          })
        }
        .layoutWeight(1)
        .width('100%')
        .divider(null)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }
}
