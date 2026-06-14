import { appNavigation, navParam } from '../data/navigation';
import { useIssueListQuery, QueryHandle } from '../queries/issue';
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
  private query: QueryHandle<ListIssuesResponse> | null = null;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.query = useIssueListQuery({ status: ['todo', 'in_progress', 'in_review'] }, () => { this.version++; });
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private queryState() {
    return this.query ? this.query.getState() : null;
  }

  private issueItems() {
    return this.queryState()?.data?.issues ?? [];
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
    if (!this.queryState()) {
      Blank().layoutWeight(1)
    } else if (this.queryState()!.isLoading) {
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
    } else if (this.queryState()!.error) {
      MulticaText({
        value: `Failed to load issues: ${this.queryState()!.error!.message}`,
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
