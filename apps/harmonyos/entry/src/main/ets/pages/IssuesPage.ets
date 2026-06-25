import { appNavigation, navParam } from '../data/navigation';
import { useIssueListQuery, QueryHandle } from '../queries/issue';
import { queryClient } from '../queries/cache';
import { ColorScheme, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { IssueRow } from '../components/issue/IssueRow';
import { Issue, ListIssuesResponse } from '../models/types';

@ComponentV2
export struct IssuesPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local _isLoading: boolean = true;
  @Local _data: ListIssuesResponse | undefined = undefined;
  @Local _error: Error | null = null;
  private query: QueryHandle<ListIssuesResponse> | null = null;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useIssueListQuery({}, () => {
      this.version++;
      this.syncFromCache();
    });
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
    this.globalUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private syncFromCache(): void {
    if (!this.query) return;
    const s = this.query.getState();
    this._isLoading = s.isLoading;
    this._data = s.data as ListIssuesResponse | undefined;
    this._error = s.error;
  }

  private issueItems(): Issue[] {
    return this._data?.issues ?? [];
  }

  build() {
    Column() {
      Header({ title: 'Issues', scheme: this.scheme })

      if (this._isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 76, radius: RADIUS.lg })
              .margin({ left: space('3'), right: space('3'), top: space('2') })
          })
        }
        .layoutWeight(1)
        .width('100%')
      } else if (this._error) {
        Column() {
          MulticaText({
            value: '加载任务失败',
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
      } else if (this.issueItems().length === 0) {
        Column() {
          MulticaText({
            value: '还没有任务',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'semibold',
            textAlign: 'center'
          })
          MulticaText({
            value: '当前空间的任务会显示在这里。',
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
          ForEach(this.issueItems(), (issue: Issue) => {
            ListItem() {
              IssueRow({
                issue: issue,
                scheme: this.scheme,
                onPress: () => { appNavigation.pushName('IssueDetailPage', navParam('id', issue.id)); }
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
