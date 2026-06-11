/**
 * parseWithFallback — the boundary defense for installed-app
 * schema drift, required by the project's "API Response
 * Compatibility" rule (root CLAUDE.md) and the iOS
 * `apps/mobile/lib/parse-response.ts` mirror.
 *
 * Why we hand-roll this instead of pulling in zod: the HarmonyOS
 * build chain (ArkTS) does not ship zod, and the platform's strict
 * type rules forbid `any`. The native zod runtime depends on
 * dynamic property access that ArkTS flags as a strict-mode
 * violation. Instead we provide a thin shim that takes a
 * `Schema<T>` (a small `validate(value): { success, data, error }`
 * function) and a fallback value. Behavior is identical to
 * `zod::safeParse → on success return parsed; on failure log +
 * return fallback (never throw into UI)`.
 *
 * Why we mirror instead of importing from packages/core: the
 * HarmonyOS app sits OUTSIDE the workspace share zone (see
 * apps/harmonyos/CLAUDE.md "What the HarmonyOS app may import
 * from elsewhere"). The iOS version lives in `apps/mobile/lib/`
 * for the same reason. Keep this in lockstep with
 * `apps/mobile/lib/parse-response.ts` — both should accept the
 * same shape of arguments and return the same shape of result.
 */

export interface ParseOptions {
  /** Stable telemetry label — typically the endpoint name
   *  (e.g. `GET /api/issues`). Falls back to `<unknown>` so the
   *  warning log is never `[api] schema validation failed: undefined`. */
  endpoint: string;
}

export interface ParseSuccess<T> {
  success: true;
  data: T;
}

export interface ParseFailure {
  success: false;
  error: string;
  issues: ReadonlyArray<string>;
}

export type ParseResult<T> = ParseSuccess<T> | ParseFailure;

/**
 * Minimal schema contract. A schema is a pure function that
 * either returns the typed value or a structured failure. The
 * implementation lives in `lib/schemas.ets` and is intentionally
 * tiny — see the rationale at the top of that file.
 */
export interface Schema<T> {
  validate(value: unknown): ParseResult<T>;
}

/**
 * Run `value` through `schema`. On success, return the typed
 * result. On failure, log a warning tagged with the endpoint
 * (so a noisy production log is still greppable) and return
 * `fallback`. Never throw into the caller — a malformed server
 * response is a recoverable runtime event, not an exception.
 */
export function parseWithFallback<T>(
  value: unknown,
  schema: Schema<T>,
  fallback: T,
  opts: ParseOptions
): T {
  const result = schema.validate(value);
  if (result.success) {
    return result.data;
  }
  console.warn(
    `[api] schema validation failed: ${opts.endpoint}`,
    { issues: result.issues, received: value }
  );
  return fallback;
}

/**
 * `null` / `undefined` / primitive short-circuit. Schemas that
 * expect an object can compose with `isObject(value)` to fail
 * fast on the common cases. Keeps the schema bodies in
 * `lib/schemas.ets` readable.
 */
export function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

/**
 * Build a failure result. Centralised so the schema code stays
 * declarative — every field-missing check looks the same.
 */
export function fail(message: string, issues: ReadonlyArray<string> = [message]): ParseFailure {
  return { success: false, error: message, issues };
}

export function ok<T>(data: T): ParseSuccess<T> {
  return { success: true, data };
}
