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
 */
export async function markInboxRead(itemId: string): Promise<void> {
  const key = ['inbox', workspaceStore.currentId];
  queryClient.setQueryData<InboxItem[]>(key, (prev) => {
    if (!prev) return prev;
    return prev.map(i => i.id === itemId ? { ...i, read: true } : i);
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
    if (!prev) return prev;
    return prev.map(i => ({ ...i, read: true }));
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
    if (!prev) return prev;
    return prev.map(i => i.id === itemId ? { ...i, archived: true } : i);
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
    if (!prev) return prev;
    return prev.map(i => ({ ...i, archived: true }));
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
    if (!prev) return prev;
    return prev.map(i => i.read ? { ...i, archived: true } : i);
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
    if (!prev) return prev;
    return prev.map(i => i.type === 'status' || i.type === 'review_request' ? { ...i, archived: true } : i);
  });
  try {
    await api.archiveCompletedInbox();
  } finally {
    queryClient.invalidate(key);
  }
}
