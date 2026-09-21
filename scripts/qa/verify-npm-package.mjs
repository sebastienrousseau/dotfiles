#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0 OR MIT
// Copyright (c) 2015-2026 Sebastien Rousseau

import { spawnSync } from "node:child_process";
import { tmpdir } from "node:os";
import { join } from "node:path";

const expected = [
  "CHANGELOG.md",
  "LICENSE-APACHE",
  "LICENSE-MIT",
  "README.md",
  "install.sh",
  "package.json",
  "tools/ci/install-chezmoi-verified.sh",
  "tools/README.md",
].sort();

const result = spawnSync(
  "npm",
  ["pack", "--dry-run", "--ignore-scripts", "--json"],
  {
    encoding: "utf8",
    env: {
      ...process.env,
      npm_config_cache:
        process.env.npm_config_cache ?? join(tmpdir(), "dotfiles-npm-cache"),
    },
  },
);

if (result.error) {
  console.error(`npm package verification failed: ${result.error.message}`);
  process.exit(1);
}
if (result.status !== 0) {
  process.stderr.write(result.stderr);
  process.exit(result.status ?? 1);
}

let report;
try {
  report = JSON.parse(result.stdout);
} catch (error) {
  console.error(`npm pack returned invalid JSON: ${error.message}`);
  process.exit(1);
}

const actual = (report[0]?.files ?? []).map(({ path }) => path).sort();
const missing = expected.filter((path) => !actual.includes(path));
const unexpected = actual.filter((path) => !expected.includes(path));

if (missing.length || unexpected.length) {
  if (missing.length) console.error(`Missing package files: ${missing.join(", ")}`);
  if (unexpected.length) console.error(`Unexpected package files: ${unexpected.join(", ")}`);
  process.exit(1);
}

const forbidden = actual.filter(
  (path) =>
    path.includes("__pycache__") ||
    path.endsWith(".pyc") ||
    path.endsWith(".log") ||
    path.endsWith(".bak") ||
    path.includes(".env"),
);
if (forbidden.length) {
  console.error(`Forbidden generated or secret-adjacent files: ${forbidden.join(", ")}`);
  process.exit(1);
}

console.log(`npm package contract verified (${actual.length} files)`);
