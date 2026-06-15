import { appNavigation, navParam } from '../data/navigation';
import { useIssueListQuery, QueryHandle } from '../queries/issue';
import { queryClient } from '../queries/cache';
import { THEME, ColorScheme, SPACE, space, themeTokens } from '../lib/theme';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { IssueRow } from '../components/issue/IssueRow';
import { Issue, ListIssuesResponse } from '../models/types';

@ComponentV2
export struct MyIssuesPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  // H-1 fix: @Local mirrors of the cache state. ArkUI only tracks
  // @Local fields that build() actually reads — see InboxPage.ets
  // for the long-form rationale.
  @Local _isLoading: boolean = true;
  @Local _data: ListIssuesResponse | undefined = undefined;
  @Local _error: Error | null = null;
  private query: QueryHandle<ListIssuesResponse> | null = null;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useIssueListQuery({ status: ['todo', 'in_progress', 'in_review'] }, () => {
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
    return 'light';
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
      Header({ title: 'My Issues', scheme: this.scheme })
      this.Body()
      this.FloatingAction()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
  }

  @Builder private Body() {
    if (this._isLoading) {
      Column() {
        ForEach([1, 2, 3, 4, 5], () => {
          Row() {
            Skeleton({ scheme: this.scheme, skeletonWidth: '85%', skeletonHeight: 18, radius: 4 })
          }
          .padding({ left: space('4'), right: space('4'), top: space('3'), bottom: space('3') })
        })
      }
      .layoutWeight(1)
      .width('100%')
    } else if (this._error) {
      MulticaText({
        value: `Failed to load issues: ${this._error.message}`,
        scheme: this.scheme,
        textSize: 'sm',
        color: 'destructive'
      })
        .padding(space('4'))
    } else if (this.issueItems().length === 0) {
      Stack({ alignContent: Alignment.Center }) {
        MulticaText({
          value: 'No open issues — you\'re all caught up!',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'mutedForeground',
          textAlign: 'center'
        })
      }
      .layoutWeight(1)
      .width('100%')
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
          .border({
            width: { bottom: 1 },
            color: String(themeTokens(this.scheme).border)
          })
        })
      }
      .layoutWeight(1)
      .width('100%')
    }
  }

  @Builder private FloatingAction() {
    Row() {
      MulticaText({
        value: '+',
        scheme: this.scheme,
        textSize: 'xl',
        weight: 'bold',
        color: 'brandForeground'
      })
    }
    .width('100%')
    .height(56)
    .backgroundColor(String(themeTokens(this.scheme).brand))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { appNavigation.pushName('NewIssuePage'); })
  }
}
