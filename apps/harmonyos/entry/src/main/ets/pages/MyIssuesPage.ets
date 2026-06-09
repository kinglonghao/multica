import { appNavigation } from '../data/navigation';
import { useIssueListQuery, QueryHandle } from '../queries/issue';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { IssueRow } from '../components/issue/IssueRow';
import { ListIssuesResponse } from '../models/types';

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

  build() {
    Column() {
      Header({ title: 'My Issues', scheme: this.scheme })

      if (!this.query) {
        return;
      }
      const state = this.query.getState();
      if (state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4, 5], () => {
            Row() {
              Skeleton({ scheme: this.scheme, width: '85%', height: 18, radius: 4 })
            }
            .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
          })
        }
      } else if (state.error) {
        MulticaText({
          value: `Failed to load issues: ${state.error!.message}`,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
      } else {
        const issues = state.data?.issues ?? [];
        if (issues.length === 0) {
          Stack({ alignContent: Alignment.Center }) {
            MulticaText({
              value: 'No open issues — you\'re all caught up!',
              scheme: this.scheme,
              size: 'sm',
              color: 'mutedForeground',
              textAlign: TextAlign.Center
            })
          }
          .layoutWeight(1)
          .width('100%')
        } else {
          List({ space: 0 }) {
            ForEach(issues, (issue) => {
              ListItem() {
                IssueRow({
                  issue: issue,
                  scheme: this.scheme,
                  onPress: () => { appNavigation.pushName('IssueDetailPage', { id: issue.id }); }
                })
              }
              .divider({ strokeWidth: 1, color: String(THEME[this.scheme].border) })
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }

      Row() {
        MulticaText({
          value: '+',
          scheme: this.scheme,
          size: 'xl',
          weight: 'bold',
          color: 'brandForeground'
        })
      }
      .width('100%')
      .height(56)
      .backgroundColor(String(THEME[this.scheme].brand))
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => { appNavigation.pushName('NewIssuePage'); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
