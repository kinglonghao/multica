import { api } from '../data/api';
import { queryClient } from '../queries/cache';
import { workspaceStore } from '../data/workspace';
import { InboxItem } from '../models/types';

/**
 * Inbox mutations. Mirrors apps/mobile/data/mutations/inbox.ts.
 *
 * Each mutation:
 *   1. Optimistically patches the cache (setQueryData) so the UI flips
 *      before the server response arrives.
 *   2. Awaits the server request.
 *   3. Settles by invalidating the inbox query key (a refetch will
 *      reconcile any drift between optimistic and server truth).
 *
 * The HarmonyOS build doesn't have react-query, so we don't get its
 * `useMutation` lifecycle for free — the same pattern is encoded by
 * hand here. Future work: move these into a small `useMutation` hook
 * that returns `{ mutate, isLoading, error }` to match the iOS API.
 *
 * ArkTS note: object spread (`{...i, read: true}`) is forbidden, so
 * the per-item optimistic patch uses `cloneInboxItem` (field-by-field
 * copy) followed by the override. The two overrides used here are
 * `read` and `archived`; any new field needs the same pattern.
 */
export function cloneInboxItem(i: InboxItem): InboxItem {
  return {
    id: i.id,
    type: i.type,
    read: i.read,
    archived: i.archived,
    issue_id: i.issue_id,
    workspace_id: i.workspace_id,
    actor_id: i.actor_id,
    actor_name: i.actor_name,
    actor_avatar_url: i.actor_avatar_url,
    details: i.details,
    created_at: i.created_at,
    updated_at: i.updated_at,
  };
}

export async function markInboxRead(itemId: string): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      if (i.id !== itemId) return i;
      const copy = cloneInboxItem(i);
      copy.read = true;
      return copy;
    });
  });
  try {
    await api.markInboxRead(itemId);
  } finally {
    queryClient.invalidate(key);
  }
}

export async function markAllInboxRead(): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      const copy = cloneInboxItem(i);
      copy.read = true;
      return copy;
    });
  });
  try {
    await api.markAllInboxRead();
  } finally {
    queryClient.invalidate(key);
  }
}

export async function archiveInboxItem(itemId: string): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      if (i.id !== itemId) return i;
      const copy = cloneInboxItem(i);
      copy.archived = true;
      return copy;
    });
  });
  try {
    await api.archiveInbox(itemId);
  } finally {
    queryClient.invalidate(key);
  }
}

export async function archiveAllInbox(): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      const copy = cloneInboxItem(i);
      copy.archived = true;
      return copy;
    });
  });
  try {
    await api.archiveAllInbox();
  } finally {
    queryClient.invalidate(key);
  }
}

export async function archiveAllReadInbox(): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      if (!i.read) return i;
      const copy = cloneInboxItem(i);
      copy.archived = true;
      return copy;
    });
  });
  try {
    await api.archiveAllReadInbox();
  } finally {
    queryClient.invalidate(key);
  }
}

export async function archiveCompletedInbox(): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return [];
    return prev.map((i): InboxItem => {
      if (i.type !== 'status' && i.type !== 'review_request') return i;
      const copy = cloneInboxItem(i);
      copy.archived = true;
      return copy;
    });
  });
  try {
    await api.archiveCompletedInbox();
  } finally {
    queryClient.invalidate(key);
  }
}
