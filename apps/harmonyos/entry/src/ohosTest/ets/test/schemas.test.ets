/**
 * Tests for the new ChatSessionSchema. The schema is the
 * gatekeeper for the createChatSession response — a drift
 * here would derail the optimistic burst (the new session
 * id is needed to seed the detail + messages caches).
 */
import { describe, it, expect } from '@ohos.hypium';
import { ChatSessionSchema } from '../../../../main/ets/lib/schemas';

export default function schemasTest(): void {
  describe('ChatSessionSchema', () => {
    it('parses a full server payload', () => {
      const raw = {
        id: 'sess-1',
        workspace_id: 'ws-1',
        agent_id: 'agent-1',
        agent_name: 'Aria',
        agent_avatar_url: 'https://cdn.example/aria.png',
        title: 'Hello',
        last_message_at: '2026-06-12T10:00:00Z',
        last_message_preview: 'world',
        unread_count: 3,
        created_at: '2026-06-12T09:00:00Z',
        updated_at: '2026-06-12T10:00:00Z'
      };
      const r = ChatSessionSchema.validate(raw);
      expect(r.ok).assertTrue();
      if (r.ok) {
        expect(r.value.id).assertEqual('sess-1');
        expect(r.value.workspace_id).assertEqual('ws-1');
        expect(r.value.unread_count).assertEqual(3);
      }
    });

    it('rejects an object without an id', () => {
      const r = ChatSessionSchema.validate({ workspace_id: 'ws-1' });
      expect(r.ok).assertFalse();
    });

    it('rejects non-object input', () => {
      const r = ChatSessionSchema.validate('not an object');
      expect(r.ok).assertFalse();
    });

    it('fills in defaults for missing optional fields', () => {
      const raw = { id: 'sess-2', workspace_id: 'ws-1' };
      const r = ChatSessionSchema.validate(raw);
      expect(r.ok).assertTrue();
      if (r.ok) {
        expect(r.value.agent_id).assertEqual(null);
        expect(r.value.title).assertEqual(null);
        expect(r.value.unread_count).assertEqual(0);
        expect(r.value.created_at).assertEqual('');
      }
    });
  });
}
