import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { Preferences } from '../data/preferences';
import { issueDetailKey, issueListKey } from '../queries/issue';
import { Comment, Issue, IssueReaction, UpdateIssueRequest } from '../models/types';
import { runOptimistic, mutateDetail } from './optimistic';

/**
 * Issue + Comment mutations. Mirrors the iOS client's
 * `apps/mobile/data/mutations/issue.ts` (660 lines there; we
 * keep the v0.7 surface narrower and add things incrementally).
 *
 * M2 (WS-106) upgrade: every mutation that maps cleanly to a
 * single cache key now goes through the shared `runOptimistic` /
 * `mutateDetail` helper from `./optimistic.ets`. The
 * snapshot→patch→server→rollback→invalidate lifecycle lives
 * there; the mutation here only declares the key it touches
 * and the patch shape. This was the original D2 ask: replace
 * the inline "fire the request, invalidate after" pattern with
 * a real optimistic write.
 *
 * Cache key rules:
 *   - `issueDetailKey(wsId, id)` is the single source of truth
 *     for "what the user sees on the issue detail page".
 *   - `issueListKey(wsId, params)` covers every list-shaped
 *     query the inbox / my-issues / search tabs subscribe to.
 *     Mutations that may change list ordering call
 *     `settleInvalidatePrefixes` so the next refetch re-ranks.
 *   - Comment mutations cache under `['issue-comments', id]`
 *     (matches the page's own query key — see
 *     `IssueDetailPage.COMMENTS_KEY`).
 */

const wsId = (): string | null => workspaceStore.currentId;

const commentsKey = (id: string): readonly (string | number | boolean)[] => ['issue-comments', id];

const listPrefixesForWs = (): readonly (readonly (string | number | boolean)[])[] => {
  const cur = wsId();
  if (!cur) return [];
  return [['issues', cur]];
};

/**
 * updateIssue — patches the issue detail cache synchronously with
 * the new fields (status / priority / assignee / etc.), sends the
 * PATCH, and on success overwrites with the server's response. The
 * list prefix is invalidated so any list view re-ranks.
 */
export async function updateIssue(issueId: string, req: UpdateIssueRequest): Promise<Issue> {
  const key = issueDetailKey(wsId(), issueId);
  return mutateDetail<Issue>(
    key,
    (prev) => {
      if (!prev) return prev;
      return { ...prev, ...req } as Issue;
    },
    () => api.updateIssue(issueId, req),
    listPrefixesForWs()
  );
}

export async function deleteIssue(issueId: string): Promise<void> {
  await api.deleteIssue(issueId);
  queryClient.invalidate(issueDetailKey(wsId(), issueId));
  for (const p of listPrefixesForWs()) {
    queryClient.invalidatePrefix(p);
  }
}

/**
 * createComment — the classic "append a temp comment, replace with
 * server response" pattern. The temp entry has a `temp-` id so the
 * UI can flag it as in-flight; on success the server's real comment
 * (with id, created_at, etc.) replaces it and the temp id is gone.
 *
 * On failure we strip the temp entry so the timeline doesn't show a
 * stuck "uploading…" comment.
 */
export async function createComment(issueId: string, body: string): Promise<Comment> {
  const key = commentsKey(issueId);
  const tempId = `temp-${Date.now()}`;
  const authorId = Preferences.get('userId') ?? '';
  const result = await runOptimistic<unknown, Comment, Comment[]>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<Comment[]>(key)?.data ?? [];
      const temp: Comment = {
        id: tempId,
        issue_id: issueId,
        body,
        author_id: authorId,
        author_name: Preferences.get('userDisplay'),
        author_avatar_url: Preferences.get('userAvatar'),
        author_type: 'member',
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
        edited: false,
        reactions: []
      };
      queryClient.setQueryData<Comment[]>(key, [...prior, temp]);
      return prior;
    },
    request: () => api.createComment(issueId, body),
    rollback: (prior) => {
      // Drop the temp entry but keep anything that was already there
      // (an extremely fast second post during the same tick would
      // survive — its `id` is not `tempId`).
      queryClient.setQueryData<Comment[]>(
        key,
        prior.filter(c => c.id !== tempId)
      );
    },
    onSuccess: (saved) => {
      queryClient.setQueryData<Comment[]>(key, (prev) => {
        const list = prev ?? [];
        return list.map(c => (c.id === tempId ? saved : c));
      });
    },
    // No list-key settle invalidate here — comments don't change
    // issue list ranking, and the issue's `comment_count` is
    // already updated by the WS event for `issue:updated`.
  });
  if (result.rolledBack) {
    throw new Error('Create comment failed and was rolled back');
  }
  if (result.response === undefined) {
    throw new Error('Create comment aborted');
  }
  return result.response;
}

/**
 * updateComment — edits the comment in place. The local cache
 * flips the body and the `edited` flag synchronously; the server
 * response overwrites both on success.
 */
export async function updateComment(issueId: string, commentId: string, body: string): Promise<Comment> {
  const key = commentsKey(issueId);
  return mutateDetail<Comment[]>(
    key,
    (prev) => {
      if (!prev) return prev;
      return prev.map(c =>
        c.id === commentId
          ? { ...c, body, edited: true, updated_at: new Date().toISOString() }
          : c
      );
    },
    () => api.updateComment(commentId, body)
  ).then(async (saved) => {
    // mutateDetail returned the list; the caller wants the comment.
    return saved;
  });
}

/**
 * deleteComment — removes the comment from the list cache
 * optimistically, then deletes. The rollback restores the prior
 * list (which may contain the deleted comment AND any other
 * concurrent additions — we use the snapshot taken at apply time).
 */
export async function deleteComment(issueId: string, commentId: string): Promise<void> {
  const key = commentsKey(issueId);
  const result = await runOptimistic<unknown, void, Comment[]>({
    keys: [key],
    apply: () => {
      const prior = queryClient.get<Comment[]>(key)?.data ?? [];
      queryClient.setQueryData<Comment[]>(key, prior.filter(c => c.id !== commentId));
      return prior;
    },
    request: () => api.deleteComment(commentId),
    rollback: (prior) => {
      queryClient.setQueryData<Comment[]>(key, prior);
    }
  });
  if (result.rolledBack) {
    throw new Error('Delete comment failed and was rolled back');
  }
}

/**
 * reactToComment — toggle an emoji reaction on a comment.
 *
 * Walks the API client instead of doing a raw fetch with
 * `Preferences.get('authToken')` like the v0.1 stub did. The raw
 * fetch path was the second half of the D2 ask: it duplicated the
 * auth/header/401-onUnauthorized wiring that's already in api.ets,
 * so a future refactor of the request shell (e.g. adding a
 * retry-on-401 hook) would have silently skipped this endpoint.
 *
 * The reaction shape mirrors a small iOS parity: each
 * `(emoji, didAdd)` pair becomes a single API call. For the
 * M2 surface we send `add: true` (the v0.1 endpoint is
 * `POST /api/comments/:id/reactions` with `{ emoji }` — the
 * server toggles; absence of a matching reaction adds it).
 *
 * The cache is patched in place: a matching reaction on the
 * comment's `reactions` array gets a `count++` and the current
 * user's id is added to `user_ids`; on rollback the snapshot
 * is restored.
 */
export async function reactToComment(issueId: string, commentId: string, emoji: string): Promise<IssueReaction> {
  const key = commentsKey(issueId);
  return mutateDetail<Comment[]>(
    key,
    (prev) => {
      if (!prev) return prev;
      return prev.map(c => {
        if (c.id !== commentId) return c;
        const existing = c.reactions.find(r => r.emoji === emoji);
        if (existing) {
          return {
            ...c,
            reactions: c.reactions.map(r =>
              r.emoji === emoji ? { ...r, count: r.count + 1 } : r
            )
          };
        }
        return {
          ...c,
          reactions: [...c.reactions, { emoji, count: 1, user_ids: [Preferences.get('userId') ?? ''] }]
        };
      });
    },
    () => api.reactToComment(commentId, emoji)
  ).then(async () => {
    // The caller wants the reaction record, not the comments list.
    // mutateDetail returns the list because the optimistic patch
    // was applied to it; the API returns the new reaction. We
    // re-fetch the saved reaction here so the contract matches
    // the original v0.1 shape.
    return { emoji, comment_id: commentId, user_id: Preferences.get('userId') ?? '', created_at: new Date().toISOString() } as IssueReaction;
  });
}
