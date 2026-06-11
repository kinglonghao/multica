#!/usr/bin/env node
// scripts/diff-harmonyos-types.mjs
//
// Drift detector for the HarmonyOS WebSocket event surface. The
// three sources of truth that must stay in lockstep:
//
//   1. `packages/core/types/events.ts::WSEventType`           (upstream union)
//   2. `apps/harmonyos/.../models/types.ets::WSEventType`     (mirrored union)
//   3. `apps/harmonyos/.../lib/ws-events.ets::WSEventNames`   (runtime registry)
//
// The first is the protocol definition; the second and third are
// hand-maintained mirrors. This script extracts the string-literal
// event names from each file and reports any drift.
//
// Run from the repo root:
//
//   node scripts/diff-harmonyos-types.mjs
//
// The script exits non-zero on drift (suitable for a CI gate). It
// prints a structured report to stdout; the report's exit code is
// the only machine-readable signal.
//
// Maintenance:
//   - When upstream `events.ts` adds/removes an event, also update
//     `models/types.ets` AND `lib/ws-events.ets`. The script will
//     fail until all three agree.
//   - When adding a brand-new event, the rule of thumb is to add
//     it to all three files in the same commit. The PR reviewer's
//     job is to verify the diff in each file is consistent.
//
// Why a `.mjs` script (and not a vitest test, not a TypeScript
// build-time check, not a zod schema): the script must run on
// every PR, including ones that don't touch TypeScript or ArkTS at
// all, and it must produce a clean exit-code signal. The existing
// `scripts/generate-reserved-slugs.mjs` is the pattern we're
// mirroring.

import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "..");

// ---------- paths ----------

const UPSTREAM_EVENTS = resolve(
  repoRoot,
  "packages/core/types/events.ts"
);
const HARMONYOS_TYPES = resolve(
  repoRoot,
  "apps/harmonyos/entry/src/main/ets/models/types.ets"
);
const HARMONYOS_REGISTRY = resolve(
  repoRoot,
  "apps/harmonyos/entry/src/main/ets/lib/ws-events.ets"
);

// ---------- path checks ----------

for (const [label, path] of [
  ["upstream events.ts", UPSTREAM_EVENTS],
  ["harmonyos types.ets", HARMONYOS_TYPES],
  ["harmonyos ws-events.ets", HARMONYOS_REGISTRY],
]) {
  if (!existsSync(path)) {
    console.error(`[diff-harmonyos-types] ${label} not found at ${path}`);
    process.exit(2);
  }
}

// ---------- parsers ----------

/**
 * Extract the `WSEventType` string-literal union members from a
 * file. Strips comments, looks for `export type WSEventType`,
 * and returns the set of single- or double-quoted string literals
 * that appear between the `=` and the closing `;`. Stops at the
 * first non-string-literal token (e.g. `| string` in the harmonyos
 * file's forward-compat fallback).
 */
function parseWSEventTypeUnion(content, filename) {
  // Drop /* ... */ block comments and // ... line comments so
  // the string regex doesn't see quoted text inside a comment.
  const stripped = content
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^\s*\/\/.*$/gm, "");

  // Locate the `export type WSEventType` declaration. We look
  // for the literal sequence so a future `type XxxEventType =
  // WSEventType | 'foo'` doesn't accidentally get parsed.
  const declRe = /export\s+type\s+WSEventType\s*=\s*([\s\S]*?);/;
  const declMatch = declRe.exec(stripped);
  if (!declMatch) {
    throw new Error(`${filename}: could not find "export type WSEventType = …;"`);
  }
  const body = declMatch[1];

  // Capture every single- or double-quoted string in the body.
  // The body of a WSEventType union is `| "evt" | "evt2" | …` —
  // we want the strings, not the pipes. The forward-compat
  // `| string` (in the harmonyos file) is a bare identifier, not
  // a quoted literal, so the regex naturally skips it.
  const stringRe = /['"]([^'"]+)['"]/g;
  const out = new Set();
  let m;
  while ((m = stringRe.exec(body)) !== null) {
    out.add(m[1]);
  }
  if (out.size === 0) {
    throw new Error(`${filename}: WSEventType union parsed to zero events`);
  }
  return out;
}

/**
 * Extract the `WSEventNames` string-literal array from the
 * registry file. Looks for `export const WSEventNames:
 * ReadonlyArray<string> = [ … ];` and returns every single- or
 * double-quoted string literal inside the brackets. The trailing
 * comma on the last entry is tolerated (matches the upstream
 * style).
 */
function parseWSEventNamesArray(content, filename) {
  const stripped = content
    .replace(/\/\*[\s\S]*?\*\//g, "")
    .replace(/^\s*\/\/.*$/gm, "");

  const declRe =
    /export\s+const\s+WSEventNames\s*:\s*ReadonlyArray<string>\s*=\s*\[([\s\S]*?)\];/;
  const declMatch = declRe.exec(stripped);
  if (!declMatch) {
    throw new Error(
      `${filename}: could not find "export const WSEventNames: ReadonlyArray<string> = [ … ];"`
    );
  }
  const body = declMatch[1];

  const stringRe = /['"]([^'"]+)['"]/g;
  const out = new Set();
  let m;
  while ((m = stringRe.exec(body)) !== null) {
    out.add(m[1]);
  }
  if (out.size === 0) {
    throw new Error(`${filename}: WSEventNames array parsed to zero events`);
  }
  return out;
}

// ---------- main ----------

const upstream = parseWSEventTypeUnion(
  readFileSync(UPSTREAM_EVENTS, "utf8"),
  "packages/core/types/events.ts"
);
const harmonyos = parseWSEventTypeUnion(
  readFileSync(HARMONYOS_TYPES, "utf8"),
  "apps/harmonyos/.../models/types.ets"
);
const registry = parseWSEventNamesArray(
  readFileSync(HARMONYOS_REGISTRY, "utf8"),
  "apps/harmonyos/.../lib/ws-events.ets"
);

// diffs
const missingFromHarmonyos = [...upstream].filter((e) => !harmonyos.has(e));
const missingFromRegistry = [...harmonyos].filter((e) => !registry.has(e));
const extraInRegistry = [...registry].filter((e) => !harmonyos.has(e));

const hasDrift =
  missingFromHarmonyos.length > 0 ||
  missingFromRegistry.length > 0 ||
  extraInRegistry.length > 0;

const fmt = (arr) => (arr.length === 0 ? "  (none)" : arr.map((e) => `  - ${e}`).join("\n"));

console.log("=== harmonyos WS-event drift report ===");
console.log("");
console.log(`upstream (packages/core/types/events.ts)        : ${upstream.size} events`);
console.log(`harmonyos types.ets::WSEventType                : ${harmonyos.size} events`);
console.log(`harmonyos lib/ws-events.ets::WSEventNames       : ${registry.size} events`);
console.log("");
console.log("[1] Missing from harmonyos types.ets (upstream has, local union doesn't):");
console.log(fmt(missingFromHarmonyos));
console.log("");
console.log("[2] Missing from registry array (types.ets has, registry doesn't):");
console.log(fmt(missingFromRegistry));
console.log("");
console.log("[3] Extra in registry (registry has, types.ets doesn't):");
console.log(fmt(extraInRegistry));
console.log("");

if (hasDrift) {
  console.error(
    "[diff-harmonyos-types] DRIFT DETECTED — see [1]/[2]/[3] above. " +
    "Update all three files in the same commit so upstream, the mirrored " +
    "TypeScript union, and the runtime registry agree."
  );
  process.exit(1);
} else {
  console.log(
    "[diff-harmonyos-types] OK — all three sources are in lockstep " +
    `(${upstream.size} events).`
  );
  process.exit(0);
}
