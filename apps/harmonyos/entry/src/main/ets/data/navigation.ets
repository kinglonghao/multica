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
 */

export interface NavParam {
  [key: string]: string | number | boolean | object | undefined;
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
   * Read a string param from the top of the stack for a given
   * destination. Used by the destination builder (destinations.ets)
   * to pass typed values into sub-page components. We isolate it
   * here so the cast lives in one well-tested place.
   */
  readString(name: string, key: string, fallback: string): string {
    const top = this.stack.getParamByName(name);
    if (!top || top.length === 0) return fallback;
    const params = top[top.length - 1];
    if (!params) return fallback;
    const v = (params as Record<string, string | number | boolean>)[key];
    return typeof v === 'string' ? v : fallback;
  }
}

export const appNavigation: AppNavigation = new AppNavigation();
export type { NavParam };
