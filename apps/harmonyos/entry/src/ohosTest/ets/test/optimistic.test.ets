/**
 * Unit tests for the shared optimistic mutation helper
 * (mutations/optimistic.ets). Covers the four lifecycle phases
 * the helper encodes:
 *
 *   1. Snapshot — captured before the request.
 *   2. Optimistic patch — applied synchronously, BEFORE the
 *      await on the request. The test asserts the cache state
 *      flips before the server resolves.
 *   3. Server settle — on success, the response is written back
 *      via onSuccess and the settle invalidate runs.
 *   4. Rollback — on a non-abort failure, the snapshot is
 *      restored and the settle invalidate still runs.
 *
 * Cancellation safety: an abort / timeout (ApiError status 0)
 * does NOT roll back. The next refetch reconciles. This test
 * verifies that contract — a 0-status error leaves the
 * optimistic patch in place (it'll be reconciled by the
 * post-abort invalidate).
 */
import { describe, it, expect, beforeEach } from '@ohos.hypium';
import { queryClient } from '../../../../main/ets/queries/cache';
import { ApiError } from '../../../../main/ets/data/api';
import { runOptimistic, mutateDetail } from '../../../../main/ets/mutations/optimistic';

interface Todo {
  id: string;
  title: string;
  done: boolean;
}

const KEY: readonly (string | number | boolean)[] = ['todo', 't-1'];

const todoOf = (overrides: Partial<Todo> = {}): Todo => ({
  id: 't-1',
  title: 'water plants',
  done: false,
  ...overrides
});

describe('optimistic helper', () => {
  beforeEach(() => {
    queryClient.clear();
  });

  it('apply runs before request resolves (true optimistic write)', async () => {
    queryClient.setQueryData<Todo>(KEY, todoOf({ done: false }));
    let cacheStateAtRequestTime: Todo | undefined;
    const result = await runOptimistic<unknown, Todo, Todo | undefined>({
      keys: [KEY],
      apply: () => {
        const prior = queryClient.get<Todo>(KEY)?.data;
        queryClient.setQueryData<Todo>(KEY, { ...prior!, done: true });
        return prior;
      },
      request: async () => {
        // Cache should already reflect the optimistic write by
        // the time the request actually fires. The original v0.1
        // inbox mutations did NOT guarantee this — that's the
        // bug the helper fixes.
        cacheStateAtRequestTime = queryClient.get<Todo>(KEY)?.data;
        return todoOf({ done: true, title: 'water plants (server)' });
      },
      rollback: () => { /* noop */ }
    });
    expect(cacheStateAtRequestTime?.done).assertEqual(true);
    expect(result.rolledBack).assertEqual(false);
    expect(result.response?.title).assertEqual('water plants (server)');
  });

  it('rollback restores the prior value on failure', async () => {
    queryClient.setQueryData<Todo>(KEY, todoOf({ done: false }));
    const result = await runOptimistic<unknown, Todo, Todo | undefined>({
      keys: [KEY],
      apply: () => {
        const prior = queryClient.get<Todo>(KEY)?.data;
        queryClient.setQueryData<Todo>(KEY, { ...prior!, done: true });
        return prior;
      },
      request: async () => {
        throw new ApiError('boom', 500);
      },
      rollback: (prior) => {
        queryClient.setQueryData<Todo>(KEY, prior);
      }
    });
    expect(result.rolledBack).assertEqual(true);
    const after = queryClient.get<Todo>(KEY)?.data;
    expect(after?.done).assertEqual(false);
  });

  it('abort (status 0) does NOT roll back the optimistic patch', async () => {
    queryClient.setQueryData<Todo>(KEY, todoOf({ done: false }));
    let threw = false;
    try {
      await runOptimistic<unknown, Todo, Todo | undefined>({
        keys: [KEY],
        apply: () => {
          const prior = queryClient.get<Todo>(KEY)?.data;
          queryClient.setQueryData<Todo>(KEY, { ...prior!, done: true });
          return prior;
        },
        request: async () => {
          throw new ApiError('aborted', 0);
        },
        rollback: () => {
          throw new Error('rollback should not fire on abort');
        }
      });
    } catch (err) {
      threw = true;
      expect((err as ApiError).status).assertEqual(0);
    }
    expect(threw).assertEqual(true);
    // The optimistic patch stays — a follow-up refetch (triggered
    // by the caller) will reconcile against server truth.
    const after = queryClient.get<Todo>(KEY)?.data;
    expect(after?.done).assertEqual(true);
  });

  it('onSuccess overwrites the cache with the server response', async () => {
    queryClient.setQueryData<Todo>(KEY, todoOf({ done: false, title: 'old' }));
    const result = await runOptimistic<unknown, Todo, Todo | undefined>({
      keys: [KEY],
      apply: () => {
        const prior = queryClient.get<Todo>(KEY)?.data;
        queryClient.setQueryData<Todo>(KEY, { ...prior!, title: 'pending' });
        return prior;
      },
      request: async () => todoOf({ title: 'server title' }),
      rollback: () => { /* noop */ },
      onSuccess: (saved) => {
        queryClient.setQueryData<Todo>(KEY, saved);
      }
    });
    expect(result.rolledBack).assertEqual(false);
    const after = queryClient.get<Todo>(KEY)?.data;
    expect(after?.title).assertEqual('server title');
  });

  it('settleInvalidatePrefixes fires on success AND failure', async () => {
    const prefix: readonly (string | number | boolean)[] = ['todos'];
    queryClient.setQueryData<Todo>(['todos', 'list-1'], todoOf());
    // Success path
    await runOptimistic<unknown, Todo, Todo | undefined>({
      keys: [KEY],
      apply: () => undefined,
      request: async () => todoOf(),
      rollback: () => { /* noop */ },
      settleInvalidatePrefixes: [prefix]
    });
    // After a settle invalidate, the list key is gone.
    expect(queryClient.get<Todo>(['todos', 'list-1'])).assertEqual(undefined);

    // Failure path — also invalidates.
    queryClient.setQueryData<Todo>(['todos', 'list-2'], todoOf());
    await runOptimistic<unknown, Todo, Todo | undefined>({
      keys: [KEY],
      apply: () => undefined,
      request: async () => { throw new ApiError('boom', 500); },
      rollback: () => { /* noop */ },
      settleInvalidatePrefixes: [prefix]
    });
    expect(queryClient.get<Todo>(['todos', 'list-2'])).assertEqual(undefined);
  });

  it('mutateDetail returns the response and patches the detail key', async () => {
    queryClient.setQueryData<Todo>(KEY, todoOf({ done: false }));
    const result = await mutateDetail<Todo>(
      KEY,
      (prev) => prev ? { ...prev, done: true } : prev,
      async () => todoOf({ done: true, title: 'server' })
    );
    expect(result.title).assertEqual('server');
    const after = queryClient.get<Todo>(KEY)?.data;
    expect(after?.done).assertEqual(true);
  });
});
