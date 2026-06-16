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
    Stack({ alignContent: Alignment.BottomEnd }) {
      Column() {
        Header({ title: 'My Issues', scheme: this.scheme })
        this.Body()
      }
      .width('100%')
      .height('100%')

      if (!this._isLoading && !this._error) {
        this.FloatingAction()
      }
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
            Skeleton({ scheme: this.scheme, skeletonWidth: '100%', skeletonHeight: 76, radius: RADIUS.lg })
          }
          .padding({ left: space('3'), right: space('3'), top: space('1.5'), bottom: space('1.5') })
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ top: space('1') })
    } else if (this._error) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          MulticaText({
            value: '加载失败',
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
        .padding(space('6'))
      }
      .layoutWeight(1)
      .width('100%')
    } else if (this.issueItems().length === 0) {
      Stack({ alignContent: Alignment.Center }) {
        Column() {
          MulticaText({
            value: '今天没有待处理事项',
            scheme: this.scheme,
            textSize: 'lg',
            weight: 'semibold',
            textAlign: 'center'
          })
          MulticaText({
            value: '你已经清空当前待办了。',
            scheme: this.scheme,
            textSize: 'sm',
            color: 'mutedForeground',
            textAlign: 'center'
          })
            .margin({ top: space('2') })
        }
      }
      .layoutWeight(1)
      .width('100%')
    } else {
      List({ space: 0 }) {
        ListItem() {
          Column() {
            Row() {
              Column() {
                MulticaText({
                  value: '进行中的事项',
                  scheme: this.scheme,
                  textSize: 'lg',
                  weight: 'bold'
                })
                MulticaText({
                  value: `${this.issueItems().length} 条需要关注`,
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'mutedForeground'
                })
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
            }
            .width('100%')

            Row() {
              MulticaText({
                value: '按最近更新排序',
                scheme: this.scheme,
                textSize: 'xs',
                color: 'mutedForeground'
              })
            }
            .margin({ top: space('2') })
            .padding({ left: space('2'), right: space('2'), top: 3, bottom: 3 })
            .borderRadius(RADIUS.full)
            .backgroundColor(String(themeTokens(this.scheme).card))
          }
          .padding({ left: space('3'), right: space('3'), top: space('3'), bottom: space('1.5') })
        }

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

        ListItem() {
          Row() {}
            .height(72)
        }
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ top: 2 })
      .divider(null)
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
    .width(52)
    .height(52)
    .margin({ right: space('4'), bottom: space('4') })
    .borderRadius(RADIUS.full)
    .backgroundColor(String(themeTokens(this.scheme).brand))
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .onClick(() => { appNavigation.pushName('NewIssuePage'); })
  }
}
