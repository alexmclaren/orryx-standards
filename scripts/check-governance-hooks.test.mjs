// Tests for check-governance-hooks.mjs.
//
// The checker exists to fail when governance.yaml stops describing reality, so
// its own failure modes are all silent-pass shaped. Two were found while writing
// it, both of which left it printing green:
//
//   1. governance.yaml has CRLF terminators. The multi-line `enforcement_levels:`
//      match failed, so assertion 3 never checked anything.
//   2. The last hook block ran to end-of-file and picked up `enabled: true` from
//      health_checks, blaming a hook that was correctly disabled.
//
// Each test below pins one of those, plus the assertions themselves. Run:
//   node --test scripts/check-governance-hooks.test.mjs
//
// Name the file, not the directory — `node --test scripts/` treats the sibling
// .ps1 and .mjs files as test files and fails on them.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const checker = join(here, 'check-governance-hooks.mjs');
const repoRoot = resolve(here, '..');
const tmp = mkdtempSync(join(tmpdir(), 'govcheck-'));

/** Run the checker against `yaml`; return {code, out}. */
function check(yaml, { crlf = false } = {}) {
  const file = join(tmp, `gov-${Math.random().toString(36).slice(2)}.yaml`);
  writeFileSync(file, crlf ? yaml.replace(/\n/g, '\r\n') : yaml);
  try {
    const out = execFileSync(process.execPath, [checker, file], {
      encoding: 'utf8',
      cwd: repoRoot,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    return { code: 0, out };
  } catch (e) {
    return { code: e.status, out: `${e.stdout}${e.stderr}` };
  }
}

const LEVELS = `
enforcement_levels:
  hard:
    can_override: false
  documented:
    can_override: true
`;

// A script path that really exists in this repo, so "declared file exists"
// passes and the test isolates the assertion it is actually about.
const REAL = '.claude/hooks/pre-edit-memory-retrieval.ts';

test('passes when every declared script exists and none claims to be enabled', () => {
  const r = check(`${LEVELS}
hooks:
  pre_edit:
    - name: "memory-retrieval"
      script: "${REAL}"
      enabled: false
`);
  assert.equal(r.code, 0, r.out);
  assert.match(r.out, /PASS \(1 declared, 2 levels/);
});

test('fails when a declared script does not exist', () => {
  const r = check(`${LEVELS}
hooks:
  pre_commit:
    - name: "lint-check"
      script: ".claude/hooks/pre-commit-lint.ts"
      enabled: false
`);
  assert.equal(r.code, 1);
  assert.match(r.out, /lint-check: declares .* no such file/);
});

test('fails when an enabled hook exists but is registered nowhere', () => {
  const r = check(`${LEVELS}
hooks:
  pre_edit:
    - name: "memory-retrieval"
      script: "${REAL}"
      enabled: true
`);
  assert.equal(r.code, 1);
  assert.match(r.out, /registered nowhere/);
});

test('fails on an enforcement_level outside the declared vocabulary', () => {
  // "soft" was retired on 2026-08-09; retiring a level must retire every claim.
  const r = check(`${LEVELS}
systems:
  quality_gates:
    enforcement_level: "soft"
`);
  assert.equal(r.code, 1);
  assert.match(r.out, /"soft" is not declared in enforcement_levels/);
});

test('reads a CRLF file — the vocabulary check must still run', () => {
  const r = check(
    `${LEVELS}
systems:
  quality_gates:
    enforcement_level: "warn"
`,
    { crlf: true },
  );
  assert.equal(r.code, 1);
  // The bug produced "no enforcement_levels: block found" instead of this.
  assert.match(r.out, /"warn" is not declared/);
  assert.doesNotMatch(r.out, /no enforcement_levels: block found/);
});

test('a later enabled: true outside the hooks list is not attributed to a hook', () => {
  const r = check(`${LEVELS}
hooks:
  post_story:
    - name: "memory-write"
      script: "${REAL}"
      enabled: false

health_checks:
  enabled: true
`);
  assert.equal(r.code, 0, r.out);
});
