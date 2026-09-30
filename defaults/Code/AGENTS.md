# AGENTS.md — Code Repositories Standard

Invariants and guidelines for AI-assisted development across all repositories in `~/Code` (`Public`, `Private`, `Work`, `Forks`). Read this before modifying any code.

Everything here applies equally to automated agents and human contributors. It is addressed to agents because agents can make breaking changes across multiple files before anyone notices.

## Start here: the order to work in

Read this whole file and the repository's own documents before changing
anything; do not rely on fragments found by searching for a keyword. Then,
for every task:

1. **Orient.** Read the nearest `AGENTS.md` (it states what the repository
   is, what its core value is, and its own rules; where it is stricter or
   more specific, it wins), then its `README.md` and contribution guide.
2. **Hygiene** (§0): clear what the health check finds.
3. **Do the task** within the invariants (§1), on the right branch (§3).
4. **Verify** (§2): the repository's single gate, then report what ran, what
   it showed, and what could not be checked.
5. **Hand over** (§4): commit with attribution, open the pull request, and
   leave merging, tagging, publishing and anything sent outside the machine
   to the human.

A repository's `AGENTS.md` should open with what the repository is and why
it exists, then its rules in the order an agent needs them, then the one
command that validates a change, then what to leave alone.

---

## 0. Hygiene First (Before Any Other Task)

The first step of every task in a repository, before any feature, fix or
release work, is to check its health and clear what the check finds. An
agent MUST NOT start the requested work on a repository that fails this
check without first fixing it, or reporting why it cannot.

1. **Dependencies and vulnerabilities.** List open Dependabot pull requests
   and alerts, code-scanning alerts and secret-scanning alerts
   (`gh pr list --author app/dependabot`, `gh api
   repos/<owner>/<repo>/{dependabot,code-scanning,secret-scanning}/alerts?state=open`),
   and the native audit (`cargo audit`/`cargo deny`, `pip-audit`,
   `npm audit`, `govulncheck`). Fix each one, or open the pull request
   that fixes it. A scanner that is switched off counts as a finding.
2. **CI on the default branch.** It must be green. A red default branch is
   fixed before anything is built on top of it.
3. **Code quality.** The linter and formatter pass with no new
   suppressions.
4. **Complexity.** Measured per function with the ecosystem's tool (§6),
   against these ceilings:

   | Metric | Ceiling per function |
   | :--- | :--- |
   | Cyclomatic (McCabe) | 10 |
   | Cognitive (SonarSource) | 15 |
   | Halstead difficulty | 30 |
   | Lines of code | 60 (and 500 per file) |

   Code an agent writes or changes MUST be within every ceiling. A function
   already over one is a finding: it must not get worse, and a function the
   task touches is brought under the ceiling in the same change. Repositories
   keep a committed baseline of existing offenders, enforced in CI, that may
   only shrink; the backlog is reduced worst-first, one reviewed change at a
   time.

Fixing a finding still follows every other rule: its own branch and pull
request, the Definition of Done (§2), and **Merge Authority (§4)**; this
section authorises preparing fixes, not merging them. Report what the check
found, what was fixed, and what remains, before starting the requested work.

---

## 1. Core Invariants (Rules With Teeth)

1. **Never edit generated output.**
   - Directories such as `.gen/`, `bin/`, `dist/`, `target/`, and generated manuals/manpages/completions are not source code.
   - If generated output is wrong, the generator or source schema is wrong. Fix the generator.

2. **Single source of truth.**
   - Never hand-write redundant copies of CLI flag lists, schemas, help tables, or API documentation. Derive them from the primary definition.

3. **Preserve documentation & license integrity.**
   - Retain existing comments, docstrings, architecture notes, and license headers. Never strip existing explanatory comments to make a diff smaller.

4. **Keep the workspace root clean.**
   - `/Users/seb/Code` MUST contain only the `Forks/`, `Private/`, `Public/`, and
     `Work/` portfolio directories plus root Markdown files that define agent or
     repository conventions.
   - Tooling, generated reports, caches, editor settings, and repository content
     MUST live below one of the four portfolio directories, never at workspace
     root.

5. **Never invent facts.**
   - Licences, versions, owners, benchmark numbers, compatibility claims,
     security properties and the provenance of a file come from evidence in
     the repository or from the user. If the evidence is missing, say so and
     ask; never fill the gap with a plausible guess.

6. **Never silence a check by feeding it.**
   - Do not add an entry to an allowlist, manifest, baseline, suppression file
     or ignore list to make a failing check pass. Fix the cause. A baseline
     (for example a complexity baseline) is only ever regenerated to record an
     improvement, never to absorb a regression.
   - Validators' own allowlists, legal texts (`LICENSE*`, `NOTICE`), and
     signing keys are left alone unless the task is explicitly about them.

7. **Fix forward, now; never "revisit later".**
   - A defect, drift or false statement found during a task is fixed in the
     same session, forward: a new commit on the active branch, or on the
     next `feat/v<next-version>` branch when the current version is already
     released. Never rewrite a published release or tag to hide it (§3,
     Published Tag Repair), and never leave it as a note to come back to.
   - "Follow-up", "later", "next time" and "out of scope for now" are not
     outcomes. If a fix genuinely cannot be made in the session (it needs a
     decision, a credential or an action only the human may take), say
     exactly what blocks it and prepare everything up to that point.
   - This does not override Merge Authority (§4), outward-facing actions
     (§1.8) or the scope rule against coupling unrelated changes: fix
     forward on the right branch, as its own commit.

8. **Humans are accountable; agents do not attest.**
   - An agent MUST NOT add a `Signed-off-by:` trailer or any other legal
     certification (a Developer Certificate of Origin, a CLA, a licence
     statement) on a person's behalf. The human who submits the work reviews
     it, certifies it, and takes responsibility for it.
   - An agent MUST NOT send anything to other people or projects on its own:
     no emails, issues or security reports filed with another project,
     registry publishes, release announcements or social posts. It prepares
     them for the human to review and send. Pushing a branch and opening a
     pull request in the user's own repository is ordinary work; merging it
     is not (§4).

---

## 2. Definition of Done (Verification Gates)

"It compiles" or "it runs locally" is not the definition of done. Before claiming completion:

- **Run Native Test Suites**:
  - Rust: `cargo test` (and `cargo clippy --all-targets` if applicable)
  - Go: `go test ./...` / `make check` / `golangci-lint run`
  - Python: `pytest` / `uv run pytest` / `ruff check`
  - JavaScript/TypeScript: `npm test` / `biome check` / `npx vitest`
  - Shell: `bats` on test scripts
- **Use the repository's single gate.** Where a repository has one command
  that runs every check CI runs (`make check`, `run-all-checks.py`,
  `cargo xtask ci`), run that and treat it as the source of truth, rather than
  choosing individual checkers by hand; the gate can grow without the agent's
  list going stale. Stage new files first when a check reads `git ls-files`,
  or it will not see them.
- **A change must not add warnings.** A new compiler, linter or type-checker
  warning is a failure, not a note.
- **Observe and Report**:
  - State explicitly what command was run and what the result was. Never assume a test passed without running it.
  - State what could not be done: a test that could not run, a platform not
    tried, a reproducer that could not be built. An unverified claim reported
    as verified costs the reviewer more than the work saved.

---

## 3. Semantic Versioning Lifecycle Rule

- **Initial Version**: All projects and repositories must start at `v0.0.1` (or `0.0.1`).
- **Increment Policy**: Every new release/iteration increments strictly by `0.0.1` (e.g., `v0.0.1` → `v0.0.2` → `v0.0.3` ... → `v0.0.999` → `v0.1.0`).
- **Milestone Maturity**: To achieve `v0.1.0`, the project must have progressed through `v0.0.999`.
- **Scope**: Mandatory standard across all repositories to allow products and communities to mature incrementally.
- **Release Branch**: Work for the next iteration MUST begin on a branch named
  `feat/v<next-version>`, where `<next-version>` is exactly `0.0.1` greater than
  the repository's current version. For example, work after `v0.0.45` belongs on
  `feat/v0.0.46`. Create or switch to this branch before modifying release-bound
  files; do not leave the work on `main` or an unrelated topic branch.
- **Single Active Release PR Invariant**: Across all repositories, there MUST be
  at most ONE active pull request targeting `main` (or the default branch), which
  MUST be the release iteration branch `feat/v<next-version>`. Never keep multiple
  open PRs targeting the default branch concurrently.
- **Branch Funneling Policy**: Any Dependabot PRs, security fixes, documentation
  updates, or auxiliary topic branches MUST NEVER be merged directly into `main`.
  They MUST ALWAYS be merged into the active `feat/v<next-version>` branch, and
  their standalone PRs targeting `main` closed. All iteration work funnels into
  the single release PR.
  - *Mechanism: commits on the branch, not pull requests into it.* Topic
    work reaches `feat/v<next-version>` as commits on it, a local merge of the
    topic branch, or a cherry-pick of a Dependabot PR's head; never as a pull
    request based on `feat/v<next-version>`. Repositories run CI only on pull
    requests into the default branch, and many carry a PR-base check that
    fails any other base on purpose (a PR into a side branch is invisible to
    CI, and is later marked merged with an empty range). The one release PR
    into the default branch is where every change gets its CI and review.
    Close the superseded topic or Dependabot PR with a comment that links
    the release PR.
- **Family Release Integration**: Where repositories form a family that shares
  one version (a lockstep ecosystem, such as a core repository and its
  satellites), a new version is a release of the whole family, and
  `feat/v<next-version>` MUST be opened in every member, not only the one
  that started it. Each member's branch is a real iteration, never a bare
  version bump. Before its release PR is ready, each member's branch MUST:
  1. **Clear its hygiene** (§0): Dependabot PRs and alerts, code-scanning and
     secret-scanning alerts, the native audit, a red CI. Each fix is merged
     into the member's `feat/v<next-version>`, never `main` (Branch Funneling).
  2. **Integrate the family's latest**: require the newest released version of
     every sibling it depends on, and adopt any shared-standard, schema or
     manifest change the iteration makes (for example a new manifest field or
     status name a sibling reads).
  3. **Triage its open issues**: fix what belongs in this version, and state in
     the release PR what is deferred and why.
  4. **Add what the version needs**: functionality or fixes a member must
     carry for the family's release to be coherent (a consumer of a changed
     format, a check that reads a renamed field).
  5. **Record it**: a `## [<next-version>]` CHANGELOG section that says what
     changed in that member, or states that nothing did beyond the version.
  A member that has never been tagged first ships at the family's current
  version rather than `0.0.1`: its untagged CHANGELOG heading is rewritten to
  that version, because an untagged section is not a release. This is the one
  exception to Initial Version above. Merge Authority (§4) is unchanged: this
  authorises preparing the branches and PRs, not merging them.
- **Release Consistency**: Before publishing, verify every version-bearing
  source, nested package manifest, lockfile root package, generated packaging
  manifest, README install example, CI/action reference, and pre-commit revision.
  Inspect the package produced by the registry dry run, not only the worktree.
- **Release Notes and Tags**: Signed annotated tag messages MUST use
  `<PROJECT_NAME> v<VERSION>`. GitHub release notes MUST summarize user-visible
  changes and include artifact checksums in the established repository format.
  A commit list alone is not a release summary.
- **Release Page Format**: Every tag MUST have a published GitHub release, and
  every release in a repository MUST follow one naming convention, style, tone
  and layout. The one exception is a floating major tag such as a GitHub
  Action's `v0`, which is a pointer moved to each release, not a version, so
  it gets no release of its own. A nested module's tag
  (`<path>/v<VERSION>`) does get one, titled after the module and marked
  not-latest. The layout is modelled on
  <https://github.com/github/github-mcp-server/releases/tag/v1.6.0>:
  - Title: `<PROJECT_NAME> <VERSION>`, the version without the `v`
    (e.g. `pain001.com 0.0.8`, like `GitHub MCP Server 1.6.0`).
  - `## Highlights ⭐️`: two to four bullets, each `* **<Feature>**: <one or
    two plain sentences on what changed for the user>`. Direct, concrete,
    friendly; no marketing adjectives.
  - `## What's Changed`: one line per merged pull request,
    `* <PR title> by @<author> in <PR URL>`, as GitHub's generate-release-notes
    API produces it. Generate it; never hand-write it. A tag with no pull
    requests before it (usually the first) lists its commits in the same
    shape, `* <subject> by @<author> in <commit URL>`.
  - `## New Contributors`: only when there are any, in the same generated form.
  - `## Checksums`: the SHA-256 of every release asset in a fenced block (this
    satisfies the checksum rule above).
  - Last line: `**Full Changelog**: <compare URL from the previous tag>`.
  Only the Highlights are written by hand; keep them in the repository (for
  example `docs/releases/v<VERSION>.md`) and compose the rest at release time.
- **Release Preflight Is Blocking**: A release or tag MUST NOT be pushed until
  an automated preflight proves that the tag target is the intended release
  commit, the annotated tag is cryptographically signed, its first message line
  is exactly `<PROJECT_NAME> v<VERSION>`, every packaged version reference is
  current, the registry dry-run archive contains current documentation and
  manifests, and the prepared release notes contain both a user-visible summary
  and artifact checksums. Treat any mismatch as a release-blocking failure.
- **Published Release Audit**: Immediately after publishing, independently read
  the remote tag object, GitHub release body, registry package contents, and
  checksums back from their published locations. Do not infer success from the
  workflow result. A release is incomplete until this audit passes.
- **Published Tag Repair**: Published tags are immutable during normal work.
  Rewriting a published tag requires the user's explicit authorization for the
  exact tag or release series, must preserve the target commit, must replace the
  tag with a signed annotated tag, and must be followed by remote signature,
  annotation, target, release-page, and registry-content verification.

---

## 4. Git & Commit Template Standards

- **Header**: `<type>: <subject>` (maximum 50 characters, imperative mood).
  - Allowed types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.
- **Body**: Explain WHAT and WHY (not HOW) — wrap strictly at 72 characters.
- **Footer**: Reference issues or breaking changes (`Fixes #123`, `BREAKING CHANGE: description`).
- **Signing & Hooks**: Repositories use SSH commit signing (`commit.gpgsign=true`) and signoffs (`format.signoff=true`). Keep commits atomic and working trees clean.
  - A commit signature proves which key made the commit. A `Signed-off-by:`
    certifies the right to contribute it, and only the human adds that (§1.8).
- **Attribution**: A commit an agent helped produce says so in a trailer:
  `Assisted-by: <agent>:<model> [<analysis tools>]`, for example
  `Assisted-by: Claude Code:claude-opus-5-5 ruff clippy`. List specialised
  analysis tools (linters, fuzzers, static analysers), not basic ones (git,
  compilers, editors). An equivalent `Co-Authored-By:` for the agent is
  acceptable; recording that an agent was involved is what matters.
- **Bug fixes** carry a `Fixes:` reference (the issue, or the commit that
  introduced the bug) and a body that states the problem, its cause, and how
  the fix was verified (§9).
- **Opaque changes** (binaries, generated or vendored files, lockfiles,
  recorded baselines) need the human-readable account in the commit message:
  what changed and why, since the diff cannot say.
- Never put a confidentiality notice or other boilerplate in a commit message
  or pull request.
- **Merge Authority**: Never merge a pull request into `main` or another
  protected branch unless the user explicitly instructs you to merge that
  specific pull request. Approval to commit, push, open a PR, fix checks, or
  continue a roadmap is not merge authorization.
- **Handover Commands**: When an action is left to the user (a merge, a
  tag, a push, anything the session may not run), give it as ONE complete
  command that works from any directory: start with
  `cd /absolute/path/to/repo &&`, name the exact PR, tag or branch, and
  include every flag. Never assume the user's shell is in the repository,
  and never split the handover across several snippets.
- **PR Descriptions**: Follow `~/Code/PR-TEMPLATE.md` exactly, including the
  section order, the `## Highlights ⭐️`, the fenced Checksums block, and the
  `**Full Changelog**` line. After the greeting, a two-line BLUF (bottom line up
  front) that announces the PR: line one begins `This PR ` and says what it does,
  line two says why it matters or the outcome. Separate the greeting and each BLUF
  line with a blank line (a single newline soft-wraps into one paragraph in
  Markdown, so the blank line is what puts each on its own line). Not a
  descriptive paragraph above the Highlights. Write like a person: direct, concrete, no filler, no AI tells.
  Never use the em dash character (`—`) anywhere in a PR body; use a comma, a
  colon, parentheses, or a spaced hyphen instead. Every PR, fork or upstream,
  opens with a bare-name greeting to the upstream maintainer on its own line,
  exactly `Hi <name>,` with no thanks or trailing clause; it is never dropped,
  even on a PR into the user's own fork. Never add a "Generated with
  Claude Code" or any other tool-attribution footer to a PR description; commit
  attribution stays in the commit trailer (`Assisted-by:`), not the PR body.
- **Fork-and-upstream flow**: For a repository the user maintains as a fork,
  the user's own fork is the source of truth, and changes reach upstream only
  through it, in this exact order:
  1. Open the change as a PR against the fork (`origin`, the user's repo).
  2. Merge it into the fork's default branch — only on the user's explicit
     instruction for that specific PR (Merge Authority above still holds).
  3. Only then open the equivalent PR to the upstream repository, from the
     same head branch (so do not delete that branch on merge).

  Never open the upstream PR before the fork PR is merged, and never merge the
  upstream PR — merging into another project's repository is the upstream
  maintainer's decision, not the user's and not the agent's, even if asked.
  Issues are filed on the fork only, never upstream.

---

## 5. Tiered Compliance Matrix

Repositories progress through three cumulative tiers. A repository MUST NOT claim
or target the next tier until every requirement in its current tier is automated
and enforced in CI. Presence of a file without an enforcement path is evidence,
not compliance.

The normative requirement identifiers are `C<category>.L<tier>`. For example,
`C6.L2` means category 6, CI Quality Gates, at L2. Each higher-tier requirement
includes every lower-tier requirement in the same category.

Audit tooling uses `L0` only to label a repository that has not yet satisfied
all L1 signals. `L0` is not a compliance tier, and percentage scores are triage
indicators rather than substitutes for the all-requirements tier gates.

| Category | L1: Foundation (Internal / Incubator) | L2: Public Standard (Production / OSS) | L3: Gold (Core Infrastructure) |
| --- | --- | --- | --- |
| **1. Identity & README** | Basic README, Quick Start, Dev setup, License. | + CI-enforced requirements, Stability guarantee, Security section. | + CI-verified install snippets, Minimum-toolchain policy matrix. |
| **2. Documentation** | Single `README.md` and basic inline code comments. | `docs/` root, Rendered user manual deployed via CI, `ARCHITECTURE.md`. | + ADRs, CI link-checking, Migration guides, 100% public API documented. |
| **3. Build & Install UX** | Native build tool works cleanly (`npm test`, `cargo build`). | + `Makefile` task runner, Generated shell completions. | + `GNUmakefile` Unix contract, Build-time generated manpages. |
| **4. Releases & Binaries** | Tagged releases, Basic Changelog. | + Automated release pipeline, Pre-built binaries for primary OS/Arch. | + Distro-agnostic static binaries (e.g., musl), Signed tags, SLSA provenance, SBOMs. |
| **5. Packaging** | None (source only) or standard registry publish. | + Container image (if applicable), Repology tracking. | + `pkg/` generators (deb, rpm, brew, nix), reproducible builds verified in CI. |
| **6. CI Quality Gates** | Lint, Format, Single OS test run. | + Test matrix (OS × Toolchain), Coverage baseline, API docs build cleanly. | + API-breakage checks, Fuzzing corpus replay, Feature powerset matrix. |
| **7. Supply Chain** | `SECURITY.md`, Basic dependency scanning (e.g., Dependabot). | + Lockfiles pinned in CI, Routine dependency advisory audits. | + OpenSSF Scorecard ≥ 9, Cryptographic signing (`KEYS.asc`), Dependency provenance. |
| **8. Community** | `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`. | + Issue/PR templates, CI docs-linting (markdownlint). | + `AGENTS.md`, `CITATION.cff`, Sub-minute Devcontainer boot. |

### 5.1 Tier declaration and classification

- A repository MAY declare its target in `.compliance.yml` using this schema:

  ```yaml
  tier: L1 # L1, L2, or L3
  criticality: incubator # incubator, standard, or core
  owner: team-or-person
  ```

- `criticality: core` requires a target of `L3`.
- Without a declaration, audit tooling uses `L1` for `Private/` and `Forks/`,
  `L2` for `Public/` and `Work/`, and reports criticality as `unclassified`.
- L3 and `core` MUST be explicit; tooling MUST NOT infer business criticality.
- Forks and vendored fixtures are audited but MUST NOT be automatically rewritten
  unless the repository is intentionally maintained as a downstream product.

---

## 6. Ecosystem Rosetta Stone

Use the native ecosystem tool. Do not impose a Rust or Unix convention when the
language has an established equivalent.

| Capability | Rust (coreutils baseline) | Python | Node.js / TypeScript | Go |
| --- | --- | --- | --- | --- |
| **Native Build & Env** | `cargo` | `uv` / `poetry` | `pnpm` / `npm` | `go mod` |
| **Task Runner** | `just` / `Makefile` | `tox` / `Makefile` | `package.json` scripts | `Makefile` / `mage` |
| **Rendered Manual** | `mdBook` | `MkDocs` (Material) / `Sphinx` | `Docusaurus` / `VitePress` | `pkgsite` / `Hugo` |
| **API Breakage CI** | `cargo-semver-checks` | `griffe` | `api-extractor` | `apidiff` / `gorelease` |
| **Manpage / CLI Gen** | `clap_mangen` | `argparse-manpage` | `yargs` / `oclif` | `cobra` (man page gen) |
| **Security / Audit CI** | `cargo-audit` / `cargo-deny` | `pip-audit` / `safety` | `npm audit` / `socket.dev` | `govulncheck` |
| **Dependency Provenance** | `cargo-vet` | `hash-checking` mode in pip | `npm provenance` | `sum.golang.org` |
| **Lint & Format** | `clippy` / `rustfmt` | `ruff` | `eslint` / `prettier` | `golangci-lint` |
| **Fuzzing Engine** | `cargo-fuzz` (libFuzzer) | `Atheris` | `Jazzer.js` | `go test -fuzz` |
| **Complexity (§0)** | `clippy` (`cognitive_complexity`, `too_many_lines`) / `rust-code-analysis` | `ruff` (`C901`) / `radon` / `complexipy` | `eslint` (`complexity`, `sonarjs/cognitive-complexity`) | `gocyclo` / `gocognit` |

---

## 7. Canonical README Standard

### 7.1 Source and routing

- `/Users/seb/Code/README-TEMPLATE.md` is the single source of truth for a
  repository's primary `README.md` layout.
- When generating or modifying a primary README, agents MUST strictly follow the
  exact layout, HTML structure, badge syntax, and header order in that template.
- Agents MUST NOT invent sections, reorder headings, or alter table formats.
- Replace every `{{UPPER_SNAKE_CASE}}` variable with repository evidence. No
  unresolved variable may remain in a committed README.
- If a required section does not apply, retain it and state the reason concisely.
- Nested READMEs for crates, packages, examples, fixtures, and generated output
  are not primary READMEs and MUST NOT be forced into the repository template.
- Preserve SPDX identifiers and use the repository's actual license. Never guess
  a license, registry URL, compatibility promise, benchmark, or security claim.

### 7.1.1 Visual demo

- Every primary README shows a visual demo directly under the badge row,
  in the template's demo block: `.github/demo.gif`, with alt text that
  says what the demo shows.
- The demo is rendered from a committed recipe, never recorded by hand:
  a VHS tape (`.github/demo.tape`, <https://github.com/charmbracelet/vhs>)
  behind a `make demo` target (or the ecosystem's task-runner
  equivalent). It runs the repository's real commands against local
  fixtures or loopback servers the repository ships, never a live
  third-party service, and shows real output. A web project may use a
  scripted browser screenshot instead of a terminal recording, under the
  same rule.
- A change that alters what the demo shows re-renders it in the same
  change. A GIF is an opaque binary: its commit message says what the
  demo shows and which command produced it (§4).

### 7.1.2 Author link on websites

- Every website under `~/Code/Public/Web`, and every generated site or
  manual a repository publishes (MkDocs, SSG, Hugo and the like), links
  the copyright line that names Sebastien Rousseau to
  <https://sebastienrousseau.com/>. The line reads
  `© <YEAR> Sebastien Rousseau`, and the link sits on the name alone:
  `© <YEAR> <a href="https://sebastienrousseau.com/" rel="author">Sebastien Rousseau</a>`,
  on every page.
- A site that names a product, a project or only its domain in the
  copyright line still reads `© <YEAR> Sebastien Rousseau`, linked the
  same way; the product name may follow in the rest of the line.
- The link is set where the footer is generated (the layout, template or
  `copyright:` setting), never page by page, and checked on the built
  output: every page carries it.
- A site whose copyright line names someone else (a client's site) is
  left as it is; the rule is about the owner's own name.

### 7.2 Tone invariants

README prose MUST be authoritative, concise, and developer-centric. Use active
voice and concrete claims. Lead with what the software does, then show how to use
it. Never use marketing fluff, filler adjectives, vague superlatives, fabricated
metrics, or unsupported guarantees. State limitations directly in “When not to
use” and keep commands runnable by copy and paste.

### 7.3 README verification

- CI MUST validate required heading order and reject unresolved template tokens.
- Install and Quick Start snippets MUST be exercised in CI when the repository
  reaches L3.
- Links MUST be checked in CI at L3.
- README rewrites MUST be based on repository source, manifests, tests, and
  policies. Existing claims are not sufficient evidence by themselves.

---

## 8. Portfolio Rollout and Enforcement

1. **Audit:** Run
   `Private/Other/code-portfolio-compliance/tools/audit_compliance.py` across
   repository roots and generate the Markdown, CSV, and JSON reports. Generated
   reports MUST NOT be hand-edited.
2. **Template:** Centralize reusable CI workflows and update consumers by pinned
   immutable references.
3. **Enforce:** Protect branches against regression once a tier is achieved.
   Coverage and compliance floors may increase but MUST NOT silently decrease.
4. **Upgrade:** Reserve 10–15% of regular engineering capacity for moving
   high-value L2 repositories to L3 without blocking feature delivery.

README remediation follows the generated safe rewrite queue one repository at a
time. Before changing a repository, read its nearest `AGENTS.md`, inspect its
working tree, fill the template only from verified local evidence, and run its
native documentation and test gates. Never mass-rewrite dirty repositories,
forks, vendored fixtures, or generated files.

---

## 9. Finding and Fixing Bugs

When an agent is asked to find or fix a bug, it follows at least these steps,
adapted from the Linux kernel's rules for AI coding assistants.

1. **Read first.** Read the repository's process documents and any document
   the request names, in full.
2. **Note where you started.** Record the commit you are looking at.
3. **Prove it is real.** For anything beyond a trivial bug, write a
   reproducer: a failing test, or a script and its output. If the bug cannot
   be reproduced, stop and say so; an unverified bug report is usually wrong,
   and it costs a maintainer the time to find that out.
4. **Fix it.** An agent able to find a bug is almost always able to fix it,
   and a fix written in the same session, with the reasoning still at hand,
   is more accurate. Finding without fixing is the rare exception.
5. **Show the fix works.** The reproducer fails before the fix and passes
   after it, the full gate passes (§2), and the change adds no warnings.
   Drop a fix that does not work and try another; never commit one that has
   not been seen to work.
6. **Commit it** on its own branch, with a message stating the problem, the
   cause, the fix and how it was verified, a `Fixes:` reference and an
   `Assisted-by:` trailer, and no `Signed-off-by:` (§4, §1.8).
7. **Classify it.** Decide from the repository's `SECURITY.md` or threat model
   whether it is a vulnerability or an ordinary bug, and route it
   accordingly: a vulnerability goes through private disclosure, never a
   public issue or pull request.
8. **Say what could not be done**: no reproducer, a fix not built on every
   platform, a test that could not run.
9. **Hand it to the human.** The agent never sends a bug report, security
   report or patch outside the machine itself (§1.8).
