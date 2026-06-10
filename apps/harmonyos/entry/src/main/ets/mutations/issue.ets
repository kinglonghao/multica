import { api, getBaseUrl } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { Preferences } from '../data/preferences';
import { issueDetailKey, issueListKey } from '../queries/issue';
import { Comment, Issue, IssueReaction, UpdateIssueRequest } from '../models/types';

/**
 * Issue + Comment mutations. Mirrors the iOS client's
 * `apps/mobile/data/mutations/issue.ts` (660 lines there; we
 * keep the v0.7 surface narrower and add things incrementally).
 *
 * Every mutation follows the same shape:
 *   1. Optimistic patch the cache (setQueryData) so the UI flips
 *      before the server response.
 *   2. Send the request.
 *   3. On settle, invalidate the related queries so the next
 *      subscriber sees server truth.
 *
 * Mutations that take rich input (an Issue object) use the
 * server's response as the new cache value (it's authoritative).
 * Mutations that only flip a boolean (read / archived) keep the
 * optimistic value and skip the refetch.
 */

const wsId = (): string | null => workspaceStore.currentId;

export async function updateIssue(issueId: string, req: UpdateIssueRequest): Promise<Issue> {
  const key = issueDetailKey(wsId(), issueId);
  // Optimistic: keep the prior issue around so the UI doesn't
  // flash; we'll overwrite with the server's response below.
  const prior = queryClient.get<Issue>(key)?.data;
  try {
    const saved = await api.updateIssue(issueId, req);
    queryClient.setQueryData<Issue>(key, saved);
    // The issue may also appear in a list cache. We invalidate the
    // list prefix so the next refetch reflects the new status /
    // priority / assignee.
    queryClient.invalidatePrefix(['issues', wsId()]);
    return saved;
  } catch (err) {
    // Rollback: write the prior value back if we had one.
    if (prior) queryClient.setQueryData<Issue>(key, prior);
    throw err;
  }
}

export async function deleteIssue(issueId: string): Promise<void> {
  const key = issueDetailKey(wsId(), issueId);
  await api.deleteIssue(issueId);
  queryClient.invalidate(key);
  queryClient.invalidatePrefix(['issues', wsId()]);
}

export async function createComment(issueId: string, body: string): Promise<Comment> {
  const saved = await api.createComment(issueId, body);
  // Invalidate the issue's timeline so the next refetch picks up
  // the new comment.
  queryClient.invalidate(issueDetailKey(wsId(), issueId));
  return saved;
}

export async function updateComment(issueId: string, commentId: string, body: string): Promise<Comment> {
  const saved = await api.updateComment(commentId, body);
  queryClient.invalidate(issueDetailKey(wsId(), issueId));
  return saved;
}

export async function deleteComment(issueId: string, commentId: string): Promise<void> {
  await api.deleteComment(commentId);
  queryClient.invalidate(issueDetailKey(wsId(), issueId));
}

export async function reactToComment(issueId: string, commentId: string, emoji: string): Promise<IssueReaction> {
  // The reaction endpoint is reached through the system fetch
  // because api.ets doesn't yet expose a typed method. Pull the
  // base URL + auth headers from the shared modules.
  const resp = await fetch(
    `${getBaseUrl()}/api/comments/${commentId}/reactions`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${Preferences.get('authToken') ?? ''}`,
        'X-Workspace-Slug': Preferences.get('workspaceSlug') ?? ''
      },
      body: JSON.stringify({ emoji })
    }
  );
  if (!resp.ok) {
    throw new Error(`reactToComment failed: ${resp.status}`);
  }
  const reaction = (await resp.json()) as IssueReaction;
  queryClient.invalidate(issueDetailKey(wsId(), issueId));
  return reaction;
}
