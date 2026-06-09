import { appNavigation } from '../data/navigation';
import { useIssueDetailQuery, QueryHandle } from '../queries/issue';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { statusLabel, priorityLabel } from '../lib/issue-status';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { Skeleton } from '../components/ui/Skeleton';
import { StatusIcon } from '../components/ui/StatusIcon';
import { PriorityIcon } from '../components/ui/PriorityIcon';
import { Avatar } from '../components/ui/Avatar';
import { IconButton } from '../components/ui/IconButton';
import { Card } from '../components/ui/Card';
import { Issue } from '../models/types';

@Entry
@ComponentV2
struct IssueDetailPage {
  @Local scheme: ColorScheme = 'light';
  @Local issueId: string = '';

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Navigation(appNavigation.stack) {
      Column() {
        Header({
          title: this.issueId ? 'Issue' : 'Loading…',
          scheme: this.scheme,
          left: this.BackButton()
        })

        if (!this.issueId) {
          MulticaText({
            value: 'No issue id provided',
            scheme: this.scheme,
            size: 'sm',
            color: 'destructive'
          })
            .padding(SPACE['4'])
        } else {
          this.Body()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(String(THEME[this.scheme].background))
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }

  @Builder Body() {
    IssueDetailBody({ issueId: this.issueId, scheme: this.scheme })
  }
}

@ComponentV2
struct IssueDetailBody {
  @Param issueId: string = '';
  @Param scheme: ColorScheme = 'light';
  @Local version: number = 0;
  private query: QueryHandle<Issue> | null = null;

  aboutToAppear(): void {
    // The query handle MUST be set up in aboutToAppear, NOT in a field
    // initializer. Field initializers run before aboutToAppear, and at
    // that point this.issueId is still '' (the parent's @Param doesn't
    // reach the child until the parent has rendered). Subscribing with
    // the empty key would have made the first fetch hit '/api/issues/'
    // and return 404 — the v0.1 bug from the code review.
    this.query = useIssueDetailQuery(this.issueId, () => { this.version++; });
  }

  aboutToDisappear(): void {
    this.query?.unsubscribe();
  }

  build() {
    if (!this.query) {
      Column() {
        Skeleton({ scheme: this.scheme, width: 80, height: 12, radius: 4 })
        Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
          .margin({ top: SPACE['2'] })
      }
      .padding(SPACE['4'])
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      return;
    }
    const state = this.query.getState();
    Scroll() {
      Column() {
        if (state.isLoading) {
          this.Loading()
        } else if (state.error) {
          this.ErrorState(state.error!.message)
        } else if (state.data) {
          const issue = state.data;
          Column() {
            MulticaText({
              value: issue.identifier,
              scheme: this.scheme,
              size: 'xs',
              color: 'mutedForeground',
              weight: 'medium'
            })
            MulticaText({
              value: issue.title,
              scheme: this.scheme,
              size: 'xl',
              weight: 'bold',
              color: 'foreground'
            })
              .margin({ top: SPACE['2'] })

            Row() {
              this.AttributeChip(issue.status, 'status')
              this.AttributeChip(issue.priority, 'priority')
            }
            .margin({ top: SPACE['3'] })

            if (issue.description) {
              Card({ scheme: this.scheme, padding: SPACE['4'], gap: SPACE['2'] }) {
                MulticaText({
                  value: issue.description,
                  scheme: this.scheme,
                  size: 'base',
                  color: 'foreground'
                })
              }
              .margin({ top: SPACE['4'] })
              .width('100%')
            }

            if (issue.assignee_name) {
              Row() {
                Avatar({ name: issue.assignee_name, url: issue.assignee_avatar_url ?? '', size: 32, scheme: this.scheme })
                MulticaText({
                  value: `Assigned to ${issue.assignee_name}`,
                  scheme: this.scheme,
                  size: 'sm',
                  color: 'foreground'
                })
                  .margin({ left: SPACE['2'] })
              }
              .margin({ top: SPACE['3'] })
            }

            MulticaText({
              value: `Created ${timeAgo(issue.created_at)} · Updated ${timeAgo(issue.updated_at)}`,
              scheme: this.scheme,
              size: 'xs',
              color: 'mutedForeground'
            })
              .margin({ top: SPACE['3'] })
          }
          .width('100%')
          .padding(SPACE['4'])
          .alignItems(HorizontalAlign.Start)
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
  }

  @Builder AttributeChip(value: string, kind: 'status' | 'priority') {
    Row() {
      if (kind === 'status') {
        StatusIcon({ status: value, scheme: this.scheme, size: 12 })
      } else {
        PriorityIcon({ priority: value, scheme: this.scheme, size: 12 })
      }
      MulticaText({
        value: kind === 'status' ? statusLabel(value) : priorityLabel(value),
        scheme: this.scheme,
        size: 'xs',
        color: 'foreground',
        weight: 'medium'
      })
        .margin({ left: SPACE['1.5'] })
    }
    .padding({ left: SPACE['2.5'], right: SPACE['2.5'], top: SPACE['1.5'], bottom: SPACE['1.5'] })
    .backgroundColor(String(THEME[this.scheme].card))
    .borderRadius(RADIUS.full)
    .margin({ right: SPACE['2'] })
  }

  @Builder Loading() {
    Column() {
      Skeleton({ scheme: this.scheme, width: 80, height: 12, radius: 4 })
      Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
        .margin({ top: SPACE['2'] })
      Skeleton({ scheme: this.scheme, width: '100%', height: 80, radius: 8 })
        .margin({ top: SPACE['4'] })
    }
    .padding(SPACE['4'])
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder ErrorState(message: string) {
    MulticaText({
      value: `Failed to load issue: ${message}`,
      scheme: this.scheme,
      size: 'sm',
      color: 'destructive'
    })
      .padding(SPACE['4'])
  }
}
