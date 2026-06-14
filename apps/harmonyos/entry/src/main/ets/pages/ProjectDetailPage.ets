import { appNavigation, navParam } from '../data/navigation';
import { useProjectDetailQuery } from '../queries/project';
import { QueryHandle } from '../queries/cache';
import { useIssueListQuery } from '../queries/issue';
import { useProjectRealtime } from '../realtime/realtime-hooks';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { timeAgo } from '../lib/utils';
import { projectStatusLabel, projectPriorityLabel } from '../lib/project-status';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { ProjectStatusIcon, ProjectPriorityIcon } from '../components/ui/ProjectStatusIcon';
import { Avatar } from '../components/ui/Avatar';
import { IssueRow } from '../components/issue/IssueRow';
import { Skeleton } from '../components/ui/Skeleton';
import { Card } from '../components/ui/Card';
import { Issue, Project, ListIssuesResponse } from '../models/types';

@ComponentV2
export struct ProjectDetailPage {
  @Param projectId: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  private project: QueryHandle<Project> | null = null;
  private issues: QueryHandle<ListIssuesResponse> | null = null;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.project = useProjectDetailQuery(this.projectId, () => { this.version++; });
    this.issues = useIssueListQuery({ project_id: this.projectId }, () => { this.version++; });
    this.wsUnsub = useProjectRealtime(this.projectId);
  }

  aboutToDisappear(): void {
    this.project?.unsubscribe();
    this.issues?.unsubscribe();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  private projectState() {
    return this.project ? this.project.getState() : null;
  }

  private issuesState() {
    return this.issues ? this.issues.getState() : null;
  }

  private projectData() {
    return this.projectState()?.data;
  }

  build() {
    Column() {
      Header({
        title: 'Project',
        scheme: this.scheme,
        left: this.BackButton()
      })
      if (!this.projectId) {
        MulticaText({
          value: 'No project id provided',
          scheme: this.scheme,
          textSize: 'sm',
          color: 'destructive'
        })
          .padding(space('4'))
      } else {
        this.Body()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(themeTokens(this.scheme).background))
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
    if (!this.projectState() || !this.issuesState()) {
      Column() {
        Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 28, radius: 6 })
      }
      .padding(space('4'))
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else {
      Scroll() {
        Column() {
          if (this.projectState()!.isLoading) {
            Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 28, radius: 6 })
          } else if (this.projectData()) {
            Stack({ alignContent: Alignment.Center }) {
              MulticaText({
                value: this.projectData()!.identifier,
                scheme: this.scheme,
                textSize: 'lg',
                weight: 'bold',
                color: 'brandForeground'
              })
            }
            .width(56)
            .height(56)
            .borderRadius(RADIUS.lg)
            .backgroundColor(String(themeTokens(this.scheme).brand))

            MulticaText({
              value: this.projectData()!.name,
              scheme: this.scheme,
              textSize: 'xl',
              weight: 'bold',
              color: 'foreground'
            })
              .margin({ top: space('3') })

            Row() {
              Row() {
                ProjectStatusIcon({ status: this.projectData()!.status, scheme: this.scheme, iconSize: 12 })
                MulticaText({
                  value: projectStatusLabel(this.projectData()!.status),
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'foreground',
                  weight: 'medium'
                })
                  .margin({ left: space('1.5') })
              }
              .padding({ left: space('2.5'), right: space('2.5'), top: space('1.5'), bottom: space('1.5') })
              .backgroundColor(String(themeTokens(this.scheme).card))
              .borderRadius(RADIUS.full)
              .margin({ right: space('2') })

              Row() {
                ProjectPriorityIcon({ priority: this.projectData()!.priority, scheme: this.scheme, iconSize: 12 })
                MulticaText({
                  value: projectPriorityLabel(this.projectData()!.priority),
                  scheme: this.scheme,
                  textSize: 'xs',
                  color: 'foreground',
                  weight: 'medium'
                })
                  .margin({ left: space('1.5') })
              }
              .padding({ left: space('2.5'), right: space('2.5'), top: space('1.5'), bottom: space('1.5') })
              .backgroundColor(String(themeTokens(this.scheme).card))
              .borderRadius(RADIUS.full)
            }
            .margin({ top: space('3') })

            if (this.projectData()!.description) {
              Column() {
                Card({ scheme: this.scheme, contentPadding: space('4') }) {
                  MulticaText({
                    value: this.projectData()!.description!,
                    scheme: this.scheme,
                    textSize: 'base',
                    color: 'foreground'
                  })
                }
              }
              .margin({ top: space('4') })
              .width('100%')
            }

            if (this.projectData()!.lead_name) {
              Row() {
                Avatar({ name: this.projectData()!.lead_name!, url: this.projectData()!.lead_avatar_url ?? '', avatarSize: 32, scheme: this.scheme })
                MulticaText({
                  value: `Lead: ${this.projectData()!.lead_name!}`,
                  scheme: this.scheme,
                  textSize: 'sm',
                  color: 'foreground'
                })
                  .margin({ left: space('2') })
              }
              .margin({ top: space('3') })
            }
          }

          MulticaText({
            value: 'Issues',
            scheme: this.scheme,
            textSize: 'md',
            weight: 'semibold',
            color: 'foreground'
          })
            .margin({ top: space('6'), bottom: space('2') })
            .width('100%')
            .padding({ left: space('4'), right: space('4') })

          if (this.issuesState()!.data?.issues) {
            Column() {
              ForEach(this.issuesState()!.data!.issues, (issue: Issue) => {
                IssueRow({
                  issue: issue,
                  scheme: this.scheme,
                  onPress: () => { appNavigation.pushName('IssueDetailPage', navParam('id', issue.id)); }
                })
              })
            }
          }
        }
        .width('100%')
        .padding(space('4'))
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .width('100%')
    }
  }
}
