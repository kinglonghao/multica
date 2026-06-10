import { appNavigation } from '../data/navigation';
import { useProjectDetailQuery, QueryHandle } from '../queries/project';
import { useIssueListQuery } from '../queries/issue';
import { useProjectRealtime } from '../realtime/realtime-hooks';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
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
import { Project, ListIssuesResponse } from '../models/types';

@ComponentV2
export struct ProjectDetailPage {
  @Local id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  private project: QueryHandle<Project> | null = null;
  private issues: QueryHandle<ListIssuesResponse> | null = null;
  private wsUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = this.detectScheme();
    this.id = appNavigation.readString('ProjectDetailPage', 'id', '');
    this.project = useProjectDetailQuery(this.id, () => { this.version++; });
    this.issues = useIssueListQuery({ project_id: this.id }, () => { this.version++; });
    this.wsUnsub = useProjectRealtime(this.id);
  }

  aboutToDisappear(): void {
    this.project?.unsubscribe();
    this.issues?.unsubscribe();
    this.wsUnsub?.();
  }

  private detectScheme(): ColorScheme {
    return 'light';
  }

  build() {
    Column() {
      Header({
        title: 'Project',
        scheme: this.scheme,
        left: this.BackButton()
      })
      if (!this.id) {
        MulticaText({
          value: 'No project id provided',
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

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: 'Back',
      onTap: () => { appNavigation.pop(); }
    })
  }

  @Builder Body() {
    if (!this.project || !this.issues) {
      Column() {
        Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
      }
      .padding(SPACE['4'])
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      return;
    }
    const pState = this.project.getState();
    const iState = this.issues.getState();
    Scroll() {
      Column() {
        if (pState.isLoading) {
          Skeleton({ scheme: this.scheme, width: '90%', height: 28, radius: 6 })
        } else if (pState.data) {
          const p = pState.data;
          Stack({ alignContent: Alignment.Center }) {
            MulticaText({
              value: p.identifier,
              scheme: this.scheme,
              size: 'lg',
              weight: 'bold',
              color: 'brandForeground'
            })
          }
          .width(56)
          .height(56)
          .borderRadius(RADIUS.lg)
          .backgroundColor(String(THEME[this.scheme].brand))

          MulticaText({
            value: p.name,
            scheme: this.scheme,
            size: 'xl',
            weight: 'bold',
            color: 'foreground'
          })
            .margin({ top: SPACE['3'] })

          Row() {
            Row() {
              ProjectStatusIcon({ status: p.status, scheme: this.scheme, size: 12 })
              MulticaText({
                value: projectStatusLabel(p.status),
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

            Row() {
              ProjectPriorityIcon({ priority: p.priority, scheme: this.scheme, size: 12 })
              MulticaText({
                value: projectPriorityLabel(p.priority),
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
          }
          .margin({ top: SPACE['3'] })

          if (p.description) {
            Card({ scheme: this.scheme, padding: SPACE['4'] }) {
              MulticaText({
                value: p.description,
                scheme: this.scheme,
                size: 'base',
                color: 'foreground'
              })
            }
            .margin({ top: SPACE['4'] })
            .width('100%')
          }

          if (p.lead_name) {
            Row() {
              Avatar({ name: p.lead_name, url: p.lead_avatar_url ?? '', size: 32, scheme: this.scheme })
              MulticaText({
                value: `Lead: ${p.lead_name}`,
                scheme: this.scheme,
                size: 'sm',
                color: 'foreground'
              })
                .margin({ left: SPACE['2'] })
            }
            .margin({ top: SPACE['3'] })
          }
        }

        MulticaText({
          value: 'Issues',
          scheme: this.scheme,
          size: 'md',
          weight: 'semibold',
          color: 'foreground'
        })
          .margin({ top: SPACE['6'], bottom: SPACE['2'] })
          .width('100%')
          .padding({ left: SPACE['4'], right: SPACE['4'] })

        if (iState.data?.issues) {
          Column() {
            ForEach(iState.data.issues, (issue) => {
              IssueRow({
                issue: issue,
                scheme: this.scheme,
                onPress: () => { appNavigation.pushName('IssueDetailPage', { id: issue.id }); }
              })
            })
          }
        }
      }
      .width('100%')
      .padding(SPACE['4'])
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .width('100%')
  }
}
