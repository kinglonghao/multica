import { api } from './api';
import { Preferences } from './preferences';
import { Workspace } from '../models/types';
import { globalEvents } from './auth';

/**
 * Workspace store. Mirrors apps/mobile/data/workspace-store.ts.
 *
 * Single source of truth for the active workspace. The X-Workspace-Slug
 * header on every API request is derived from this store — switching
 * workspace in the UI immediately retargets subsequent fetches.
 */

interface WorkspaceSnapshot {
  workspaces: Workspace[];
  current: Workspace | null;
  loading: boolean;
  error: string | null;
}

type Listener = (s: WorkspaceSnapshot) => void;

class WorkspaceStore {
  private snapshot: WorkspaceSnapshot = {
    workspaces: [],
    current: null,
    loading: false,
    error: null
  };
  private readonly listeners = new Set<Listener>();

  getState(): WorkspaceSnapshot {
    return this.snapshot;
  }

  get currentId(): string | null {
    return this.snapshot.current?.id ?? null;
  }

  get currentSlug(): string | null {
    return this.snapshot.current?.slug ?? null;
  }

  subscribe(listener: Listener): () => void {
    this.listeners.add(listener);
    listener(this.snapshot);
    return () => this.listeners.delete(listener);
  }

  private set(patch: Partial<WorkspaceSnapshot>): void {
    this.snapshot = { ...this.snapshot, ...patch };
    for (const l of this.listeners) l(this.snapshot);
  }

  async loadFromStorage(): Promise<void> {
    const id = Preferences.get('workspaceId');
    const slug = Preferences.get('workspaceSlug');
    if (id && slug) {
      this.set({ current: { id, slug, name: slug } });
    }
  }

  async fetchWorkspaces(): Promise<Workspace[]> {
    this.set({ loading: true, error: null });
    try {
      const list = await api.listWorkspaces();
      this.set({ workspaces: list, loading: false });
      // If we have a stored current workspace, find it in the list and
      // use its fresh name. Otherwise, default to the first one.
      const id = Preferences.get('workspaceId');
      const match = list.find(w => w.id === id) ?? list[0] ?? null;
      if (match) {
        await this.setCurrent(match.id, match.slug);
      }
      return list;
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'Failed to load workspaces';
      this.set({ loading: false, error: msg });
      throw err;
    }
  }

  async setCurrent(id: string | null, slug: string | null): Promise<void> {
    await Preferences.setWorkspace(id, slug);
    const current = id && slug
      ? (this.snapshot.workspaces.find(w => w.id === id) ?? { id, slug, name: slug })
      : null;
    this.set({ current });
    globalEvents.emit('workspace:changed');
  }

  async clear(): Promise<void> {
    await Preferences.setWorkspace(null, null);
    this.set({ current: null });
  }
}

export const workspaceStore: WorkspaceStore = new WorkspaceStore();
