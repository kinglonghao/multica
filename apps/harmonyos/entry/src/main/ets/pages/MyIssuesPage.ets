import router from '@ohos.router';
import { useIssueListQuery } from '../queries/issue';
import { authStore } from '../data/auth';
import { THEME, ColorScheme, SPACE } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { IssueRow } from '../components/issue/IssueRow';

@Component
export struct MyIssuesPage {
  @State scheme: ColorScheme = 'light';
  @State refreshing: boolean = false;
  private query = useIssueListQuery({ status: ['todo', 'in_progress', 'in_review'] });

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({ title: 'My Issues', scheme: this.scheme })

      if (this.query.state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4, 5], () => {
            Row() {
              Skeleton({ scheme: this.scheme, width: '85%', height: 18, radius: 4 })
            }
            .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['3'], bottom: SPACE['3'] })
          })
        }
      } else if (this.query.state.error) {
        MulticaText({
          value: `Failed to load issues: ${this.query.state.error!.message}`,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .padding(SPACE['4'])
      } else {
        const issues = this.query.state.data?.issues ?? [];
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
                  onPress: () => { router.pushUrl({ url: 'pages/IssueDetailPage', params: { id: issue.id } }); }
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
      .onClick(() => { router.pushUrl({ url: 'pages/NewIssuePage' }); })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }
}
