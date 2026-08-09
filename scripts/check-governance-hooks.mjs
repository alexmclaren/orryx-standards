#!/usr/bin/env node
// hook_scripts_exist — the health check governance.yaml has specified since
// 2026-05-18 (line 395, `critical: true`) and never had.
//
// Why it exists: governance.yaml declared thirteen hooks at enforcement_level
// "hard". Nine of the scripts were never written, and no settings.json anywhere
// in this repository has ever registered any of them, so the four that do exist
// never fired either. The config described a target state as though it were the
// current one for eleven weeks, and nothing could tell the difference.
//
// Three assertions, no dependencies:
//   1. Every `script:` declared in governance.yaml exists on disk.
//   2. Every hook with `enabled: true` is registered with Claude Code via a
//      settings.json, or invoked by a workflow. Existing is not running.
//   3. Every `enforcement_level:` value is one of the keys declared under
//      `enforcement_levels:` — so retiring a level from the vocabulary
//      mechanically retires every claim to it.
//
// Deliberately regex, not a YAML parser: the three things being checked are all
// single-line scalars, and a parser would mean a dependency in a repo that has
// none. If governance.yaml ever grows anchors or multi-line script paths, this
// is the file to upgrade. (ponytail: line-scalar regex, swap for a YAML parse
// if the config stops being flat.)

import { readFileSync, existsSync, readdirSync, statSync } from 'node:fs';
import { join, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..');
// argv override exists so the test can point at fixtures. Nothing else uses it.
const configPath = process.argv[2]
  ? resolve(process.argv[2])
  : join(repoRoot, '.claude/config/governance.yaml');
const failures = [];

if (!existsSync(configPath)) {
  console.error(`FAIL  governance.yaml not found at ${configPath}`);
  process.exit(1);
}
// Normalise CRLF. This repo is Windows-primary and governance.yaml has CRLF
// terminators; without this the multi-line `enforcement_levels:` match fails and
// assertion 3 reports "no vocabulary" instead of checking one — a silent pass
// dressed as a loud failure.
const config = readFileSync(configPath, 'utf8').replace(/\r\n/g, '\n');

// --- Collect every file that could register or invoke a hook -----------------
// Anything under .github/, plus any settings.json outside node_modules.
function walk(dir, out = []) {
  if (!existsSync(dir)) return out;
  for (const entry of readdirSync(dir)) {
    if (entry === 'node_modules' || entry === '.git') continue;
    const p = join(dir, entry);
    if (statSync(p).isDirectory()) walk(p, out);
    else out.push(p);
  }
  return out;
}
const registrars = [
  ...walk(join(repoRoot, '.github')),
  ...walk(repoRoot).filter((p) => /settings(\.\w+)?\.json$/.test(p)),
];
const registrarText = registrars.map((p) => readFileSync(p, 'utf8')).join('\n');

// --- 1 & 2: declared scripts exist, and enabled ones are registered ----------
// Hook entries are `- name:` blocks; read each block's script/enabled together
// so an enabled flag is never attributed to the wrong hook.
// A hook entry's keys are all indented, so a block ends at the first
// non-indented line. Without this the final block runs to end-of-file and reads
// `enabled: true` from an unrelated section further down — health_checks did
// exactly that, and the checker blamed the wrong hook.
function untilDedent(block) {
  const lines = block.split('\n');
  const end = lines.findIndex((line, i) => i > 0 && /^\S/.test(line));
  return (end === -1 ? lines : lines.slice(0, end)).join('\n');
}

const blocks = config.split(/^\s*- name:/m).slice(1).map(untilDedent);
let declared = 0;
for (const block of blocks) {
  const script = block.match(/^\s*script:\s*"?([^"\n]+?)"?\s*$/m)?.[1];
  if (!script) continue;
  declared += 1;
  const name = block.split('\n')[0].trim().replace(/^["']|["']$/g, '');
  // Tolerate a trailing comment, or `enabled: true  # why` reads as disabled.
  const enabled = /^\s*enabled:\s*true\s*(#.*)?$/m.test(block);

  if (!existsSync(join(repoRoot, script))) {
    failures.push(`${name}: declares '${script}' — no such file`);
    continue;
  }
  if (enabled && !registrarText.includes(script)) {
    failures.push(
      `${name}: enabled: true but '${script}' is registered nowhere — ` +
        'no settings.json or workflow references it, so it never fires',
    );
  }
}

// --- 3: no claim to an enforcement level that is not in the vocabulary -------
const vocabBlock = config.match(/^enforcement_levels:\n((?:[ \t]+.*\n|\n)*)/m)?.[1] ?? '';
const vocabulary = [...vocabBlock.matchAll(/^ {2}([a-z_]+):/gm)].map((m) => m[1]);
if (vocabulary.length === 0) failures.push('no enforcement_levels: block found');

for (const m of config.matchAll(/^\s*enforcement_level:\s*"?([a-z_]+)"?/gm)) {
  if (!vocabulary.includes(m[1])) {
    failures.push(
      `enforcement_level: "${m[1]}" is not declared in enforcement_levels ` +
        `(${vocabulary.join(', ')})`,
    );
  }
}

// --- Report -----------------------------------------------------------------
if (failures.length) {
  console.error('hook_scripts_exist: FAIL\n');
  for (const f of failures) console.error(`  - ${f}`);
  console.error(
    '\ngovernance.yaml must describe reality. Either build and register the ' +
      'hook, or remove the declaration.',
  );
  process.exit(1);
}
console.log(
  `hook_scripts_exist: PASS (${declared} declared, ${vocabulary.length} levels: ${vocabulary.join(', ')})`,
);
