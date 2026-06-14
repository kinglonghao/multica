import { WSEnvelope, WSEventType } from '../models/types';

interface WSRawEnvelope {
  event?: string;
  payload?: Object | string | number | boolean | null;
  ts?: string;
}

/**
 * Validates a raw WS message string into a typed `WSEnvelope`. Mirrors
 * the iOS client's runtime validation (H-5) — without this, a malformed
 * payload would crash the first handler that assumed the typed shape.
 *
 * The validation here is intentionally light (a hand-rolled type guard
 * instead of a zod schema) because the platform doesn't ship zod and
 * the envelope shape is small. New fields are tolerated as long as the
 * three required fields (`event`, `payload`, `ts`) are present and
 * `event` is a string. Unknown event names are accepted — handlers
 * registered for that name will fire; everything else is dropped.
 */
export const parseWSEnvelope: (raw: string) => WSEnvelope<Object | string | number | boolean | null> | null =
  (raw: string): WSEnvelope<Object | string | number | boolean | null> | null => {
    let parsed: Object | string | number | boolean | null = null;
    try {
      parsed = JSON.parse(raw);
    } catch {
      console.warn('[ws-validate] JSON.parse failed');
      return null;
    }
    if (typeof parsed !== 'object' || parsed === null) {
      console.warn('[ws-validate] not an object');
      return null;
    }
    const obj = parsed as WSRawEnvelope;
    if (typeof obj.event !== 'string') {
      console.warn('[ws-validate] missing or non-string `event`');
      return null;
    }
    if (typeof obj.ts !== 'string') {
      console.warn('[ws-validate] missing or non-string `ts`');
      return null;
    }
    const event = obj.event as WSEventType;
    const ts = obj.ts;
    const payload = obj.payload ?? null;
    return { event, payload, ts };
  };
