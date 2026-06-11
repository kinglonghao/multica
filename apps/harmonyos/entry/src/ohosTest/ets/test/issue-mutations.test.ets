/**
 * Issue + comment mutations (M2) — reuses the same mocked-api
 * pattern as `mutations.test.ets` but covers the WS-106 fixes
 * specifically:
 *
 *   1. `updateComment` returns the **single updated comment**,
 *      not the full list. (The v0.1 stub wrapped `mutateDetail`
 *      in a no-op `.then` and returned the list — that bug
 *      was a typing lie: callers thought they had a Comment
 *      but got Comment[]. The M2 version finds the row in
 *      the patched list and returns it.)
 *   2. `reactToComment` returns the **server's IssueReaction**
 *      (with canonical id + created_at), not a locally
 *      constructed stub. The cache holds one row per
 *      (comment, emoji, user) tuple — no count aggregate.
 *   3. `createComment` inserts a temp row, the server's row
 *      replaces it, and the temp id is gone from the cache.
 *   4. All three mutations roll the cache back to its prior
 *      value on a 5xx failure.
 */
import { describe, it, expect, beforeEach } from '@ohos.hypium';
import { queryClient } from '../../../../main/ets/queries/cache';
import { ApiError } from '../../../../main/ets/data/api';
import { Comment, IssueReaction } from '../../../../main/ets/models/types';
import {
  createComment,
  updateComment,
  deleteComment,
  reactToComment
} from '../../../../main/ets/mutations/issue';

const KEY = (id: string): readonly (string | number | boolean)[] => ['issue-comments', id];

const mkComment = (overrides: Partial<Comment> = {}): Comment => ({
  id: 'c-1',
  issue_id: 'i-1',
  body: 'hello',
  author_id: 'u-1',
  author_name: 'Alice',
  author_avatar_url: null,
  author_type: 'member',
  created_at: '2026-06-09T00:00:00Z',
  updated_at: '2026-06-09T00:00:00Z',
  edited: false,
  reactions: [],
  ...overrides
});

/**
 * Replace the api.ets `request` method with an in-memory mock
 * for the duration of one test. The mock returns whatever
 * response the test sets in `nextResponse`, or throws the
 * `nextError`. The test must reset the original method via
 * the returned `restore` callback.
 */
type Restore = () => void;

function mockApi(response?: unknown, error?: Error): Restore {
  // The api module exports a singleton `api`; we monkey-patch
  // the four mutation methods we exercise. The real surface is
  // untouched for callers that don't run this test.
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  const apiModule = require('../../../../main/ets/data/api');
  const realCreate = apiModule.api.createComment.bind(apiModule.api);
  const realUpdate = apiModule.api.updateComment.bind(apiModule.api);
  const realDelete = apiModule.api.deleteComment.bind(apiModule.api);
  const realReact = apiModule.api.reactToComment.bind(apiModule.api);
  apiModule.api.createComment = async () => (response as Comment) ?? mkComment({ id: 'c-server' });
  apiModule.api.updateComment = async () => (response as Comment) ?? mkComment({ body: 'patched', edited: true });
  apiModule.api.deleteComment = async () => { if (error) throw error; };
  apiModule.api.reactToComment = async () => (response as IssueReaction) ?? ({
    id: 'r-server',
    comment_id: 'c-1',
    emoji: '👍',
    user_id: 'u-1',
    created_at: '2026-06-09T00:00:01Z'
  } as IssueReaction);
  return (): void => {
    apiModule.api.createComment = realCreate;
    apiModule.api.updateComment = realUpdate;
    apiModule.api.deleteComment = realDelete;
    apiModule.api.reactToComment = realReact;
  };
}

describe('issue mutations (M2)', () => {
  beforeEach(() => {
    queryClient.clear();
  });

  it('createComment: temp row is replaced with server row on success', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [mkComment({ id: 'c-existing' })]);
    const restore = mockApi(mkComment({ id: 'c-server', body: 'new' }));
    try {
      const saved = await createComment('i-1', 'new');
      expect(saved.id).assertEqual('c-server');
      const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
      // Both rows present, temp id is gone.
      const ids = list.map(c => c.id);
      expect(ids.includes('c-server')).assertEqual(true);
      expect(ids.find(i => i.startsWith('temp-'))).assertEqual(undefined);
    } finally {
      restore();
    }
  });

  it('createComment: rolls back (removes the temp row) on 5xx', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [mkComment({ id: 'c-existing' })]);
    const restore = mockApi(undefined, new ApiError('boom', 500));
    let threw = false;
    try {
      await createComment('i-1', 'will fail');
    } catch (err) {
      threw = true;
    } finally {
      restore();
    }
    expect(threw).assertEqual(true);
    const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
    // Pre-existing row is preserved; temp row is gone.
    const ids = list.map(c => c.id);
    expect(ids).assertEqual(['c-existing']);
  });

  it('updateComment: returns the single updated comment (not the list)', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [
      mkComment({ id: 'c-1', body: 'old' }),
      mkComment({ id: 'c-2', body: 'other' })
    ]);
    const restore = mockApi(mkComment({ id: 'c-1', body: 'patched', edited: true }));
    try {
      const updated = await updateComment('i-1', 'c-1', 'patched');
      // Critical: must be a Comment, NOT Comment[].
      expect((updated as Comment).id).assertEqual('c-1');
      expect((updated as Comment).body).assertEqual('patched');
      expect((updated as Comment).edited).assertEqual(true);
      const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
      const c1 = list.find(c => c.id === 'c-1');
      expect(c1?.body).assertEqual('patched');
    } finally {
      restore();
    }
  });

  it('updateComment: rolls back to prior body on 5xx', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [mkComment({ id: 'c-1', body: 'old' })]);
    const restore = mockApi(undefined, new ApiError('boom', 500));
    let threw = false;
    try {
      await updateComment('i-1', 'c-1', 'will fail');
    } catch (err) {
      threw = true;
    } finally {
      restore();
    }
    expect(threw).assertEqual(true);
    const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
    expect(list[0]?.body).assertEqual('old');
  });

  it('reactToComment: returns the server reaction and appends a row', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [mkComment({ id: 'c-1' })]);
    const restore = mockApi({
      id: 'r-server',
      comment_id: 'c-1',
      emoji: '👍',
      user_id: 'u-1',
      created_at: '2026-06-09T00:00:01Z'
    } as IssueReaction);
    try {
      const reaction = await reactToComment('i-1', 'c-1', '👍');
      expect(reaction.id).assertEqual('r-server');
      const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
      const rows = list[0]?.reactions ?? [];
      // Server row is in the list; temp id is gone.
      expect(rows.find(r => r.id === 'r-server')).assertNotEqual(undefined);
      expect(rows.find(r => r.id?.startsWith('temp-'))).assertEqual(undefined);
    } finally {
      restore();
    }
  });

  it('deleteComment: removes the row and rolls back on 5xx', async () => {
    queryClient.setQueryData<Comment[]>(KEY('i-1'), [
      mkComment({ id: 'c-1' }),
      mkComment({ id: 'c-2' })
    ]);
    const restore = mockApi(undefined, new ApiError('boom', 500));
    let threw = false;
    try {
      await deleteComment('i-1', 'c-1');
    } catch (err) {
      threw = true;
    } finally {
      restore();
    }
    expect(threw).assertEqual(true);
    const list = queryClient.get<Comment[]>(KEY('i-1'))?.data ?? [];
    expect(list.map(c => c.id)).assertEqual(['c-1', 'c-2']);
  });
});
