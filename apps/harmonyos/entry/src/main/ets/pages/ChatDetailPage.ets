import { appNavigation } from '../data/navigation';
import { api } from '../data/api';
import { useQuery, QueryHandle } from '../queries/cache';
import { useChatRealtime } from '../realtime/realtime-hooks';
import { ChatMessage, ChatSession } from '../models/types';
import { THEME, ColorScheme, SPACE, RADIUS } from '../lib/theme';
import { themeController } from '../lib/theme-controller';
import { localeController, t } from '../lib/locale';
import { Preferences } from '../data/preferences';
import { timeAgo } from '../lib/utils';
import { MulticaText } from '../components/ui/Text';
import { Header } from '../components/ui/Header';
import { IconButton } from '../components/ui/IconButton';
import { Avatar } from '../components/ui/Avatar';
import { Skeleton } from '../components/ui/Skeleton';
import { ChatComposer } from '../components/chat/ChatComposer';
import { MessageBubble } from '../components/chat/MessageBubble';

@ComponentV2
export struct ChatDetailPage {
  @Local id: string = '';
  @Local scheme: ColorScheme = 'light';
  @Local version: number = 0;
  @Local inputDraft: string = '';
  @Local sending: boolean = false;
  @Local sendError: string = '';
  private session: QueryHandle<ChatSession> | null = null;
  private messages: QueryHandle<ChatMessage[]> | null = null;
  private wsUnsub?: () => void;
  private themeUnsub?: () => void;
  private localeUnsub?: () => void;

  aboutToAppear(): void {
    this.scheme = themeController.scheme;
    this.themeUnsub = themeController.subscribe((s) => { this.scheme = s; });
    this.localeUnsub = localeController.subscribe(() => { this.version++; });
    this.id = appNavigation.readString('ChatDetailPage', 'id', '');
    this.session = useQuery<ChatSession>(
      ['chat-session', this.id],
      ({ signal }) => api.getChatSession(this.id, { signal }),
      { staleTimeMs: 30_000, onUpdate: () => { this.version++; } }
    );
    this.messages = useQuery<ChatMessage[]>(
      ['chat-messages', this.id],
      ({ signal }) => api.listChatMessages(this.id, { signal }),
      { staleTimeMs: 10_000, onUpdate: () => { this.version++; } }
    );
    // Subscribe to chat:message events for this session. The
    // hook patches the cache in place — incoming assistant
    // messages stream in without a refetch.
    this.wsUnsub = useChatRealtime(this.id);
    // Restore the per-session draft from the shared preferences
    // store. We save on every change so a kill-and-relaunch
    // (or a quick tab-switch) preserves the in-flight text.
    void this.restoreDraft();
  }

  aboutToDisappear(): void {
    this.session?.unsubscribe();
    this.messages?.unsubscribe();
    this.wsUnsub?.();
    this.themeUnsub?.();
    this.localeUnsub?.();
  }

  private async restoreDraft(): Promise<void> {
    if (!this.id) return;
    this.inputDraft = await Preferences.getChatDraft(this.id);
  }

  private async persistDraft(value: string): Promise<void> {
    if (!this.id) return;
    await Preferences.setChatDraft(this.id, value);
  }

  private async send(): Promise<void> {
    const text = this.inputDraft.trim();
    if (!text || this.sending) return;
    this.sending = true;
    this.sendError = '';
    try {
      await api.sendChatMessage(this.id, text);
      this.inputDraft = '';
      await this.persistDraft('');
      // Refetch on send so the user's message + the agent's
      // eventual response both land; the WS hook handles the
      // interim assistant message.
      this.messages?.refetch();
    } catch (err) {
      this.sendError = err instanceof Error ? err.message : t('chat_message_failed');
    } finally {
      this.sending = false;
    }
  }

  build() {
    Column() {
      Header({
        title: this.session?.getState().data?.title ?? t('chat_title'),
        scheme: this.scheme,
        left: this.BackButton()
      })

      if (!this.messages) {
        return;
      }
      const mState = this.messages.getState();
      const sState = this.session?.getState();
      const session = sState?.data;
      Scroll() {
        Column() {
          if (mState.isLoading) {
            ForEach([1, 2, 3], () => {
              Skeleton({ scheme: this.scheme, width: '90%', height: 40, radius: 8 })
                .margin({ top: SPACE['2'], left: SPACE['4'], right: SPACE['4'] })
            })
          } else if (mState.data) {
            if (mState.data.length === 0) {
              MulticaText({
                value: t('chat_no_messages'),
                scheme: this.scheme,
                size: 'sm',
                color: 'mutedForeground',
                textAlign: TextAlign.Center
              })
                .width('100%')
                .padding(SPACE['6'])
            } else {
              ForEach(mState.data, (msg: ChatMessage) => {
                MessageBubble({
                  message: msg,
                  scheme: this.scheme,
                  agentName: session?.agent_name ?? ''
                })
              })
            }
          }
        }
        .width('100%')
        .padding({ top: SPACE['2'], bottom: SPACE['2'] })
      }
      .layoutWeight(1)
      .width('100%')

      if (this.sendError) {
        MulticaText({
          value: this.sendError,
          scheme: this.scheme,
          size: 'xs',
          color: 'destructive'
        })
          .width('100%')
          .padding({ left: SPACE['4'], right: SPACE['4'], top: SPACE['1'] })
      }

      ChatComposer({
        value: this.inputDraft,
        scheme: this.scheme,
        placeholder: t('chat_composer_placeholder'),
        sending: this.sending,
        onChange: (v: string) => {
          this.inputDraft = v;
          void this.persistDraft(v);
        },
        onSend: () => { void this.send(); }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(String(THEME[this.scheme].background))
  }

  @Builder BackButton() {
    IconButton({
      glyph: '‹',
      scheme: this.scheme,
      accessibilityLabel: t('common_back'),
      onTap: () => { appNavigation.pop(); }
    })
  }
}
