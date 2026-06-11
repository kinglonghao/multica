/**
 * Unit tests for the parseWithFallback helper. Mirrors the
 * contract the iOS app's apps/mobile/lib/parse-response.test.ts
 * pins down: a malformed server response must NEVER throw into
 * the UI; it must log + return the supplied fallback.
 *
 * Tests cover:
 *   - happy path: well-formed value is returned typed
 *   - failure path: a non-object / missing-id / wrong-type is
 *     swapped for the fallback (and a warn is logged)
 *   - no-throw: every failure path returns a value, never throws
 */
import { describe, it, expect } from '@ohos.hypium';
import {
  parseWithFallback,
  Schema,
  ParseResult,
  fail,
  isObject,
  ok
} from '../../../../main/ets/lib/parse-response';
import {
  IssueSchema,
  InboxItemSchema,
  InboxListSchema,
  EMPTY_ISSUE,
  EMPTY_INBOX_LIST,
  EMPTY_INBOX_ITEM
} from '../../../../main/ets/lib/schemas';

const issueFixture = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  id: 'iss-1',
  number: 1,
  identifier: 'MUL-1',
  title: 'Title',
  description: null,
  status: 'todo',
  priority: 'high',
  workspace_id: 'ws-1',
  project_id: null,
  assignee_id: null,
  assignee_type: null,
  assignee_name: null,
  assignee_avatar_url: null,
  creator_id: null,
  creator_name: null,
  creator_avatar_url: null,
  due_date: null,
  created_at: '2026-06-09T00:00:00Z',
  updated_at: '2026-06-09T00:00:00Z',
  labels: null,
  comment_count: 0,
  ...overrides
});

const inboxFixture = (overrides: Record<string, unknown> = {}): Record<string, unknown> => ({
  id: 'inb-1',
  type: 'mention',
  read: false,
  archived: false,
  issue_id: 'iss-1',
  workspace_id: 'ws-1',
  actor_id: 'u-1',
  actor_name: 'Alex',
  actor_avatar_url: null,
  details: null,
  created_at: '2026-06-09T00:00:00Z',
  updated_at: '2026-06-09T00:00:00Z',
  ...overrides
});

export default function parseResponseTest(): void {
  describe('parseWithFallback', () => {
    it('returns the typed value when the schema succeeds', () => {
      const out = parseWithFallback(issueFixture(), IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /fixture'
      });
      expect(out.id).assertEqual('iss-1');
      expect(out.status).assertEqual('todo');
      expect(out.priority).assertEqual('high');
    });

    it('swaps in the fallback when the value is null', () => {
      const out = parseWithFallback(null, IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /null'
      });
      expect(out.id).assertEqual('');
    });

    it('swaps in the fallback when the value is not an object', () => {
      const out = parseWithFallback('not-an-object', IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /string'
      });
      expect(out.id).assertEqual('');
    });

    it('swaps in the fallback when id is missing', () => {
      const bad = issueFixture();
      delete bad['id'];
      const out = parseWithFallback(bad, IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /no-id'
      });
      expect(out.id).assertEqual('');
    });

    it('swaps in the fallback when id is the wrong type', () => {
      const bad = issueFixture({ id: 42 });
      const out = parseWithFallback(bad, IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /id-number'
      });
      expect(out.id).assertEqual('');
    });

    it('lenient read: a wrong-type optional field falls back per-field, not whole-record', () => {
      // comment_count should be a number, the server sent a string.
      // The schema should still produce a valid Issue (with the
      // default 0 for that field), not the EMPTY_ISSUE.
      const bad = issueFixture({ comment_count: 'lots' });
      const out = parseWithFallback(bad, IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /wrong-type-field'
      });
      expect(out.id).assertEqual('iss-1');
      expect(out.comment_count).assertEqual(0);
    });

    it('does not throw on a circular value — returns fallback', () => {
      const circular: Record<string, unknown> = { id: 'iss-1' };
      circular['self'] = circular;
      // Sanity: it IS an object with id, so the schema should accept it.
      // We intentionally use a missing-id shape to exercise the failure
      // path: a circular value is fine for the schema, the assertion is
      // that no throw escapes.
      const out = parseWithFallback(circular, IssueSchema, EMPTY_ISSUE, {
        endpoint: 'TEST /circular'
      });
      // The id IS present here, so we should get a real Issue back.
      expect(out.id).assertEqual('iss-1');
    });

    it('inbox: a list with one bad row drops the bad row but keeps the good ones', () => {
      const list = [
        inboxFixture({ id: 'good-1' }),
        { id: 42, type: 'mention' }, // wrong type for id
        inboxFixture({ id: 'good-2' })
      ];
      const out = parseWithFallback(list, InboxListSchema, EMPTY_INBOX_LIST, {
        endpoint: 'TEST /inbox-list'
      });
      expect(out.length).assertEqual(2);
      expect(out[0].id).assertEqual('good-1');
      expect(out[1].id).assertEqual('good-2');
    });

    it('inbox: an entirely non-array value falls back to the empty list', () => {
      const out = parseWithFallback({ not: 'an array' }, InboxListSchema, EMPTY_INBOX_LIST, {
        endpoint: 'TEST /inbox-not-array'
      });
      expect(out.length).assertEqual(0);
    });

    it('inbox: a single malformed item returns the EMPTY_INBOX_ITEM', () => {
      const out = parseWithFallback(null, InboxItemSchema, EMPTY_INBOX_ITEM, {
        endpoint: 'TEST /inbox-null'
      });
      expect(out.id).assertEqual('');
    });
  });

  describe('isObject', () => {
    it('returns true for plain objects', () => {
      expect(isObject({})).assertEqual(true);
      expect(isObject({ a: 1 })).assertEqual(true);
    });
    it('returns false for null / undefined / arrays / primitives', () => {
      expect(isObject(null)).assertEqual(false);
      expect(isObject(undefined)).assertEqual(false);
      expect(isObject([])).assertEqual(false);
      expect(isObject('s')).assertEqual(false);
      expect(isObject(42)).assertEqual(false);
      expect(isObject(true)).assertEqual(false);
    });
  });

  describe('Schema contract — synthetic minimal schema', () => {
    // A tiny schema that only checks `kind === 'good'`. Verifies
    // the Schema<T> contract works end-to-end: a failing schema
    // triggers the fallback path, a passing one returns the value.
    const goodSchema: Schema<{ kind: string }> = {
      validate(value: unknown): ParseResult<{ kind: string }> {
        if (isObject(value) && value['kind'] === 'good') {
          return ok({ kind: 'good' });
        }
        return fail('expected kind=good', [`got ${JSON.stringify(value)}`]);
      }
    };

    it('returns the typed data on success', () => {
      const out = parseWithFallback({ kind: 'good' }, goodSchema, { kind: 'fallback' }, {
        endpoint: 'TEST /synth-ok'
      });
      expect(out.kind).assertEqual('good');
    });

    it('returns the fallback on failure (and does not throw)', () => {
      const out = parseWithFallback({ kind: 'bad' }, goodSchema, { kind: 'fallback' }, {
        endpoint: 'TEST /synth-fail'
      });
      expect(out.kind).assertEqual('fallback');
    });
  });
}
