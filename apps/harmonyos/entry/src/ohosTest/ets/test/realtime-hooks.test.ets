/**
 * Unit tests for the realtime hooks. The hooks themselves only
 * call into `wsClient.on(...)` and `queryClient.{setQueryData,
 * invalidate, invalidatePrefix}` — both of which are pure-ish
 * modules we can drive directly.
 *
 * These tests verify the wire-up: a subscribed hook receives the
 * matching event and patches the right cache key. The actual
 * `wsClient.on()` callback is what's installed by the hook, and
 * the test fires synthetic envelopes through the same channel.
 */
import { describe, it, expect, beforeEach } from '@ohos.hypium';
import { queryClient } from '../../../../main/ets/queries/cache';
import { wsClient } from '../../../../main/ets/realtime/ws-client';
import {
  useIssueRealtime,
  useInboxRealtime,
  useProjectRealtime,
  useChatRealtime,
  usePresenceRealtime
} from '../../../../main/ets/realtime/realtime-hooks';
import { Issue, Project, InboxItem } from '../../../../main/ets/models/types';

const mkIssue = (overrides: Partial<Issue>): Issue => ({
  id: 'iss-1', number: 1, identifier: 'MUL-1', title: 't', description: '',
  status: 'todo', priority: 'no_priority', workspace_id: 'ws-1',
  created_at: '2026-06-09T00:00:00Z', updated_at: '2026-06-09T00:00:00Z',
  ...overrides
});

const mkProject = (overrides: Partial<Project>): Project => ({
  id: 'prj-1', name: 'p', identifier: 'P', description: '',
  status: 'planned', priority: 'no_priority', workspace_id: 'ws-1',
  created_at: '2026-06-09T00:00:00Z', updated_at: '2026-06-09T00:00:00Z',
  ...overrides
});

function fireEvent(event: string, payload: unknown): void {
  // wsClient stores handlers in a Map<event, Set<handler>>. We
  // can't reach into the private map from outside, so the hook
  // itself is the dispatcher — registering a probe before the
  // hook fires lets us observe the patch via the public surface.
  // For these tests we register a probe via the cache directly:
  // the hook's handler also writes to the cache, so we just
  // verify the cache state after firing.
  //
  // Reach into wsClient via a narrow cast — the public surface
  // doesn't expose `dispatch`. We tolerate the cast in tests
  // because we own both sides.
  const w = wsClient as unknown as { handlers: Map<string, Set<(env: unknown) => void>> };
  const set = w.handlers?.get(event);
  if (set) {
    for (const h of set) h({ event, payload, ts: '2026-06-09T00:00:00Z' });
  }
}

export default function realtimeHooksTest(): void {
  beforeEach(() => {
    queryClient.clear();
  });

  describe('useIssueRealtime (per-record)', () => {
    it('patches the issue detail cache on issue:updated', () => {
      queryClient.setQueryData<Issue>(['issue', 'ws-1', 'iss-1'], mkIssue({ id: 'iss-1', title: 'old' }));
      const unsub = useIssueRealtime('iss-1');
      fireEvent('issue:updated', { id: 'iss-1', issue: mkIssue({ id: 'iss-1', title: 'new' }) });
      const after = queryClient.get<Issue>(['issue', 'ws-1', 'iss-1']);
      expect(after?.data?.title).assertEqual('new');
      unsub();
    });

    it('ignores events for other issues', () => {
      queryClient.setQueryData<Issue>(['issue', 'ws-1', 'iss-1'], mkIssue({ id: 'iss-1', title: 't1' }));
      const unsub = useIssueRealtime('iss-1');
      fireEvent('issue:updated', { id: 'iss-2', issue: mkIssue({ id: 'iss-2', title: 't2' }) });
      const after = queryClient.get<Issue>(['issue', 'ws-1', 'iss-1']);
      expect(after?.data?.title).assertEqual('t1');
      unsub();
    });
  });

  describe('useInboxRealtime', () => {
    it('invalidates the inbox list cache on inbox:created', () => {
      queryClient.setQueryData<InboxItem[]>(['inbox', 'ws-1'], [{ id: 'i-1', type: 'mention', read: false, archived: false, workspace_id: 'ws-1', created_at: '', updated_at: '' }]);
      const unsub = useInboxRealtime();
      fireEvent('inbox:created', { id: 'i-new' });
      // After invalidation, get returns undefined; refetch would
      // repopulate.
      const after = queryClient.get<InboxItem[]>(['inbox', 'ws-1']);
      expect(after).assertEqual(undefined);
      unsub();
    });
  });

  describe('useProjectRealtime (per-record)', () => {
    it('patches the project detail cache on project:updated', () => {
      queryClient.setQueryData<Project>(['project', 'ws-1', 'prj-1'], mkProject({ id: 'prj-1', name: 'old' }));
      const unsub = useProjectRealtime('prj-1');
      fireEvent('project:updated', { id: 'prj-1', project: mkProject({ id: 'prj-1', name: 'new' }) });
      const after = queryClient.get<Project>(['project', 'ws-1', 'prj-1']);
      // v1.0: the cache must hold the Project object, not the
      // envelope. If the envelope slipped in, the name field
      // would be undefined (Project has no `project` sub-key).
      expect(after?.data?.name).assertEqual('new');
      expect((after?.data as unknown as { project?: unknown })?.project).assertEqual(undefined);
      unsub();
    });

    it('ignores events for other projects', () => {
      queryClient.setQueryData<Project>(['project', 'ws-1', 'prj-1'], mkProject({ id: 'prj-1', name: 't1' }));
      const unsub = useProjectRealtime('prj-1');
      fireEvent('project:updated', { id: 'prj-2', project: mkProject({ id: 'prj-2', name: 't2' }) });
      const after = queryClient.get<Project>(['project', 'ws-1', 'prj-1']);
      expect(after?.data?.name).assertEqual('t1');
      unsub();
    });
  });

  describe('useIssueRealtime comment + reaction subscriptions', () => {
    it('invalidates the comment list on comment:created for this issue', () => {
      queryClient.setQueryData<unknown[]>(['issue-comments', 'iss-1'], [{ id: 'c-old' }]);
      const unsub = useIssueRealtime('iss-1');
      fireEvent('comment:created', { id: 'c-new', issue_id: 'iss-1' });
      const after = queryClient.get<unknown[]>(['issue-comments', 'iss-1']);
      // Invalidation drops the cache entry; get returns undefined.
      expect(after).assertEqual(undefined);
      unsub();
    });

    it('ignores comment events for other issues', () => {
      queryClient.setQueryData<unknown[]>(['issue-comments', 'iss-1'], [{ id: 'c-old' }]);
      const unsub = useIssueRealtime('iss-1');
      fireEvent('comment:created', { id: 'c-new', issue_id: 'iss-2' });
      const after = queryClient.get<unknown[]>(['issue-comments', 'iss-1']);
      // The cache entry should still be there — the comment is
      // for a different issue.
      expect(after?.data?.length).assertEqual(1);
      unsub();
    });

    it('invalidates the comment list on reaction:added', () => {
      queryClient.setQueryData<unknown[]>(['issue-comments', 'iss-1'], [{ id: 'c-1' }]);
      const unsub = useIssueRealtime('iss-1');
      fireEvent('reaction:added', { comment_id: 'c-1', issue_id: 'iss-1' });
      const after = queryClient.get<unknown[]>(['issue-comments', 'iss-1']);
      expect(after).assertEqual(undefined);
      unsub();
    });
  });

  describe('useChatRealtime', () => {
    it('appends the message to the cached list on chat:message', () => {
      queryClient.setQueryData<unknown[]>(['chat-messages', 'sess-1'], [{ id: 'm-old' }]);
      const unsub = useChatRealtime('sess-1');
      fireEvent('chat:message', { session_id: 'sess-1', message: { id: 'm-new' } });
      const after = queryClient.get<unknown[]>(['chat-messages', 'sess-1']);
      expect((after?.data as unknown[])?.length).assertEqual(2);
      expect(((after?.data as unknown[])?.[1] as { id: string })?.id).assertEqual('m-new');
      unsub();
    });

    it('is a no-op when sessionId is null', () => {
      const unsub = useChatRealtime(null);
      expect(typeof unsub).assertEqual('function');
      unsub();
    });
  });

  describe('usePresenceRealtime', () => {
    it('writes the agent status to the presence cache', () => {
      const unsub = usePresenceRealtime();
      fireEvent('presence:update', { agent_id: 'agent-1', status: 'busy' });
      const after = queryClient.get<{ status: string }>(['agent-presence', 'agent-1']);
      expect(after?.data?.status).assertEqual('busy');
      unsub();
    });
  });
}
