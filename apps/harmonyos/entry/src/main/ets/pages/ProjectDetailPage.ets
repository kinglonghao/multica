import { appNavigation, navParam } from '../data/navigation';
import { useProjectDetailQuery } from '../queries/project';
import { QueryHandle, queryClient } from '../queries/cache';
import { useIssueListQuery } from '../queries/issue';
import { useProjectRealtime } from '../realtime/realtime-hooks';
import { THEME, ColorScheme, SPACE, RADIUS, space, themeTokens } from '../lib/theme';
import { detectSystemColorScheme } from '../lib/theme-manager';
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
  // H-1 fix: @Local mirrors. See InboxPage.ets.
  @Local _projectIsLoading: boolean = true;
  @Local _project: Project | undefined = undefined;
  @Local _projectError: Error | null = null;
  @Local _issuesIsLoading: boolean = true;
  @Local _issues: ListIssuesResponse | undefined = undefined;
  @Local _issuesError: Error | null = null;
  private project: QueryHandle<Project> | null = null;
  private issues: QueryHandle<ListIssuesResponse> | null = null;
  private wsUnsub?: () => void;
  private globalUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.project = useProjectDetailQuery(this.projectId, () => { this.version++; this.syncFromCache(); });
    this.issues = useIssueListQuery({ project_id: this.projectId }, () => { this.version++; this.syncFromCache(); });
    this.globalUnsub = queryClient.onAnyStateChange(() => { this.syncFromCache(); });
    this.syncFromCache();
    this.wsUnsub = useProjectRealtime(this.projectId);
  }

  aboutToDisappear(): void {
    this.project?.unsubscribe();
    this.issues?.unsubscribe();
    this.wsUnsub?.();
    this.globalUnsub?.();
  }

    private detectScheme(): ColorScheme {
    return detectSystemColorScheme();
  }

  private syncFromCache(): void {
    if (this.project) {
      const s = this.project.getState();
      this._projectIsLoading = s.isLoading;
      this._project = s.data as Project | undefined;
      this._projectError = s.error;
    }
    if (this.issues) {
      const s = this.issues.getState();
      this._issuesIsLoading = s.isLoading;
      this._issues = s.data as ListIssuesResponse | undefined;
      this._issuesError = s.error;
    }
  }

  build() {
    Column() {
      Header({
        title: 'Project',
        scheme: this.scheme,
        left: this.BackButton
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
    if (this._projectIsLoading) {
      Column() {
        Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 28, radius: 6 })
      }
      .padding(space('4'))
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    } else if (this._projectError) {
      MulticaText({
        value: `Failed to load project: ${this._projectError.message}`,
        scheme: this.scheme,
        textSize: 'sm',
        color: 'destructive'
      })
        .padding(space('4'))
    } else if (this._project) {
      Scroll() {
        Column() {
          Stack({ alignContent: Alignment.Center }) {
            MulticaText({
              value: '📁',
              scheme: this.scheme,
              textSize: 'xl',
              weight: 'medium'
            })
          }
          .width(56)
          .height(56)
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(themeTokens(this.scheme).card))
          .border({ width: 1, color: String(themeTokens(this.scheme).border) })

          MulticaText({
            value: this._project!.name,
            scheme: this.scheme,
            textSize: 'xl',
            weight: 'bold',
            color: 'foreground'
          })
            .margin({ top: space('3') })

          Row() {
            Row() {
              ProjectStatusIcon({ status: this._project!.status, scheme: this.scheme, iconSize: 12 })
              MulticaText({
                value: projectStatusLabel(this._project!.status),
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
              ProjectPriorityIcon({ priority: this._project!.priority, scheme: this.scheme, iconSize: 12 })
              MulticaText({
                value: projectPriorityLabel(this._project!.priority),
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

          if (this._project!.description) {
            Column() {
              Card({ scheme: this.scheme, contentPadding: space('4') }) {
                MulticaText({
                  value: this._project!.description!,
                  scheme: this.scheme,
                  textSize: 'base',
                  color: 'foreground'
                })
              }
            }
            .margin({ top: space('4') })
            .width('100%')
          }

          if (this._project!.lead_name) {
            Row() {
              Avatar({ name: this._project!.lead_name!, url: this._project!.lead_avatar_url ?? '', avatarSize: 32, scheme: this.scheme })
              MulticaText({
                value: `Lead: ${this._project!.lead_name!}`,
                scheme: this.scheme,
                textSize: 'sm',
                color: 'foreground'
              })
                .margin({ left: space('2') })
            }
            .margin({ top: space('3') })
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

          if (this._issuesIsLoading) {
            ForEach([1, 2, 3], () => {
              Skeleton({ scheme: this.scheme, skeletonWidth: '90%', skeletonHeight: 56, radius: 8 })
                .margin({ top: space('2'), left: space('4'), right: space('4') })
            })
          } else if (this._issuesError) {
            MulticaText({
              value: `Failed to load issues: ${this._issuesError.message}`,
              scheme: this.scheme,
              textSize: 'sm',
              color: 'destructive'
            })
              .padding({ left: space('4'), right: space('4') })
          } else if (this._issues?.issues) {
            Column() {
              ForEach(this._issues!.issues, (issue: Issue) => {
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
