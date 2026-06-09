/**
 * Unit tests for the WS envelope validator (H-5). The validator
 * turns a raw `string` from the socket into a typed `WSEnvelope` or
 * `null`. Without it, a malformed payload crashes handlers.
 */
import { describe, it, expect } from '@ohos.hypium';
import { parseWSEnvelope } from '../../../../main/ets/lib/ws-validate';

export default function wsValidateTest(): void {
  describe('parseWSEnvelope', () => {
    it('returns a typed envelope for a well-formed JSON message', () => {
      const raw = JSON.stringify({
        event: 'inbox:created',
        payload: { id: '1', type: 'mention' },
        ts: '2026-06-09T00:00:00Z'
      });
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(false);
      expect(out!.event).assertEqual('inbox:created');
      expect(out!.ts).assertEqual('2026-06-09T00:00:00Z');
    });

    it('returns null on invalid JSON', () => {
      const out = parseWSEnvelope('not-json');
      expect(out === null).assertEqual(true);
    });

    it('returns null when event is missing', () => {
      const raw = JSON.stringify({ payload: {}, ts: 'now' });
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(true);
    });

    it('returns null when event is not a string', () => {
      const raw = JSON.stringify({ event: 123, payload: {}, ts: 'now' });
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(true);
    });

    it('returns null when ts is missing', () => {
      const raw = JSON.stringify({ event: 'issue:updated', payload: {} });
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(true);
    });

    it('returns null for non-object JSON (e.g. an array)', () => {
      const raw = JSON.stringify([1, 2, 3]);
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(true);
    });

    it('returns null for the literal "null"', () => {
      const out = parseWSEnvelope('null');
      expect(out === null).assertEqual(true);
    });

    it('tolerates unknown event names — handlers decide what to do with them', () => {
      const raw = JSON.stringify({
        event: 'something:brand_new_in_a_future_server_version',
        payload: { foo: 'bar' },
        ts: 'now'
      });
      const out = parseWSEnvelope(raw);
      expect(out === null).assertEqual(false);
      expect(out!.event).assertEqual('something:brand_new_in_a_future_server_version');
    });
  });
}
