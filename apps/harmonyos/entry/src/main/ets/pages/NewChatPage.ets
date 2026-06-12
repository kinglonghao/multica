import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle, queryClient } from '../queries/cache';
import { Agent } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { themeController } from '../lib/theme-controller';
import { localeController, t } from '../lib/locale';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';
import { ChatEmptyState } from '../components/chat/ChatEmptyState';

/**
 * New chat picker. Lists the agents available in the current
 * workspace; tap one to create a chat session and open the
 * detail page. Mirrors the iOS `AgentPickerSheet` shape but as
 * a full page (HarmonyOS doesn't have a sheet primitive that
 * maps 1:1 to `UISheetPresentationController`).
 */
@ComponentV2
export struct NewChatPage {
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local creatingId: string = '';
  @Local errorMessage: string = '';
  private agents: QueryHandle<Agent[]> | null = null;
  private themeUnsub?: () => void;
  private localeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.localeUnsub = localeController.subscribe(() => { this.version++; });
    this.agents = useQuery<Agent[]>(
      ['agents'],
      ({ signal }) => api.listAgents({ signal }),
      { staleTimeMs: 60_000, onUpdate: () => { this.version++; } }
    );
  }

  aboutToDisappear(): void {
    this.agents?.unsubscribe();
    this.themeUnsub?.();
    this.localeUnsub?.();
  }

  private async pickAgent(agent: Agent): Promise<void> {
    if (this.creatingId) return;
    this.creatingId = agent.id;
    this.errorMessage = '';
    try {
      const session = await api.createChatSession({ agent_id: agent.id });
      // Bust the session list cache so the new session shows up
      // in the Chat tab on back.
      queryClient.invalidatePrefix(['chat-sessions']);
      appNavigation.pushName('ChatDetailPage', { id: session.id });
    } catch (err) {
      this.errorMessage = err instanceof Error ? err.message : t('chat_message_failed');
    } finally {
      this.creatingId = '';
    }
  }

  build() {
    Column() {
      Header({
        title: t('chat_new_chat'),
        scheme: this.scheme,
        left: this.CancelButton()
      })

      if (!this.agents) {
        return;
      }
      const state = this.agents.getState();
      if (state.isLoading) {
        Column() {
          ForEach([1, 2, 3, 4], () => {
            Row() {
              Skeleton({ scheme: this.scheme, width: 40, height: 40, radius: 20 })
              Column() {
                Skeleton({ scheme: this.scheme, width: '60%', height: 14, radius: 4 })
                Skeleton({ scheme: this.scheme, width: '40%', height: 12, radius: 4 })
                  .margin({ top: SPACE['1.5'] })
              }
              .layoutWeight(1)
              .margin({ left: SPACE['3'] })
              .alignItems(HorizontalAlign.Start)
            }
            .padding(SPACE['4'])
          })
        }
      } else {
        const agents = state.data ?? [];
        if (agents.length === 0) {
          ChatEmptyState({
            scheme: this.scheme,
            title: t('chat_empty'),
            description: t('chat_no_messages')
          })
        } else {
          List({ space: 0 }) {
            ForEach(agents, (agent: Agent) => {
              ListItem() {
                Row() {
                  Avatar({
                    name: agent.name ?? agent.slug ?? '·',
                    url: agent.avatar_url ?? '',
                    size: 40,
                    scheme: this.scheme
                  })
                  Column() {
                    MulticaText({
                      value: agent.name ?? agent.slug ?? 'Agent',
                      scheme: this.scheme,
                      size: 'base',
                      weight: 'medium',
                      color: 'foreground'
                    })
                    if (agent.description) {
                      MulticaText({
                        value: agent.description,
                        scheme: this.scheme,
                        size: 'sm',
                        color: 'mutedForeground',
                        maxLines: 1,
                        overflow: 'ellipsis'
                      })
                        .margin({ top: SPACE['0.5'] })
                    }
                  }
                  .layoutWeight(1)
                  .margin({ left: SPACE['3'] })
                  .alignItems(HorizontalAlign.Start)

                  if (this.creatingId === agent.id) {
                    MulticaText({
                      value: '…',
                      scheme: this.scheme,
                      size: 'lg',
                      color: 'mutedForeground'
                    })
                  }
                }
                .padding(SPACE['4'])
                .onClick(() => { void this.pickAgent(agent); })
              }
              .divider({ strokeWidth: 1, color: String(THEME[this.scheme].border) })
            })
          }
          .layoutWeight(1)
          .width('100%')
        }
      }

      if (this.errorMessage) {
        MulticaText({
          value: this.errorMessage,
          scheme: this.scheme,
          size: 'sm',
          color: 'destructive'
        })
          .width('100%')
          .padding(SPACE['3'])
          .backgroundColor(String(THEME[this.scheme].card))
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder CancelButton() {
    IconButton({
      glyph: '×',
      scheme: this.scheme,
      accessibilityLabel: t('common_cancel'),
      onTap: () => { appNavigation.pop(); }
    })
  }
}
