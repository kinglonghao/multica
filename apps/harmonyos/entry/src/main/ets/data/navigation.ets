/**
 * App-wide navigation. Replaces @ohos.router (deprecated, not allowed
 * in new ArkUI V2 apps) with `Navigation` + `NavPathStack`.
 *
 * Architecture (C-6):
 *   - Index.ets is the ONLY `@Entry` in the app. It mounts a single
 *     root `Navigation(appNavigation.stack)` and registers a destination
 *     builder via `.navDestination(...)`.
 *   - Every other page is a plain `@ComponentV2` struct (not `@Entry`).
 *     It does NOT wrap itself in `Navigation(...)` — that's the root's
 *     job. Pages receive their nav params as `@Param` from the
 *     destination builder, not from a `stack.getParamByName` call
 *     inside `aboutToAppear` (C-7).
 *   - Pages push / pop / replace via the helpers below; the helpers
 *     delegate to `appNavigation.stack` so the call site is short
 *     and the routing logic stays in one place.
 *
 * ArkTS notes (C-1):
 *   - The original `NavParam` was an indexed-signature interface
 *     (`[key: string]: string | number | boolean | object | undefined`).
 *     ArkTS 1.1 strict mode rejects indexed signatures, AND forbids
 *     direct `obj[key]` indexed access on a bare `Object`. We
 *     collapse the design to a single `(key, value)` pair per
 *     `pushName` call (which is all every call site needs — the
 *     `key` is just a human-readable label; the `value` is the only
 *     thing the destination builder reads), and expose typed
 *     accessors on the class.
 *   - `readString` is also simplified: the caller used to pass
 *     `key` so the helper could look the value up by name. The
 *     ArkTS-safe version reads the single stored `value` directly.
 *     The `key` parameter is kept on the call site for readability
 *     and is no longer used at runtime.
 */

export class NavParam {
  /** Human-readable label. Optional — the runtime never reads it
   *  (the destination builder reads `value` directly). Kept for
   *  debug logs and call-site readability. */
  public key: string = '';
  public value: string | number | boolean | object | undefined = undefined;
}

export function navParam(key: string, value: string | number | boolean | object | undefined): NavParam {
  return { key, value } as NavParam;
}

class AppNavigation {
  readonly stack: NavPathStack = new NavPathStack();

  /** Push a destination by name. The destination builder
   *  (pages/destinations.ets) renders the right component. */
  pushName(name: string, param?: NavParam): void {
    this.stack.pushPath({ name, param });
  }

  replaceName(name: string, param?: NavParam): void {
    this.stack.replacePath({ name, param });
  }

  pop(): void {
    if (this.stack.size() > 0) {
      this.stack.pop();
    }
  }

  clear(): void {
    this.stack.clear();
  }

  size(): number {
    return this.stack.size();
  }

  /**
   * Read the string value from the top of the stack for a given
   * destination. Used by the destination builder (destinations.ets)
   * to pass typed values into sub-page components. We isolate it
   * here so the cast lives in one well-tested place.
   *
   * The `key` parameter is kept on the signature so existing
   * call-sites (`readString('VerifyPage', 'email', '')`) still
   * compile, but the runtime no longer needs it — every
   * `pushName` call stores a single `(key, value)` pair and
   * we read `value` directly.
   */
  readString(name: string, _key: string, fallback: string): string {
    const top = this.stack.getParamByName(name) as Object[] | undefined;
    if (!top || top.length === 0) return fallback;
    const params = top[top.length - 1];
    if (!params) return fallback;
    const v = (params as NavParam).value;
    return typeof v === 'string' ? v : fallback;
  }
}

export const appNavigation: AppNavigation = new AppNavigation();
