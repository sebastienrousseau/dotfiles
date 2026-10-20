# ADR-020: One command grammar for the dot family

Status: Accepted 2026-10-18; registries, manifest schema, plugin manifests
and the CLI-contract lint implemented; alias table and generators pending
(see Enforcement).

## Context

`dot` has 105 routes in one flat table (`lib/dot/data/routes.txt`). Names
grew one at a time: `secrets-init`, `ssh-key`, `load-bench-pty`, `ai-query`,
`dns-doh`. Some are verbs, some nouns, some both; `doctor`, `health` and
`health-check` overlap; `dot -v` prints the version where GNU tools mean
verbose. The family is about to split into one repository per domain
(plan v3), and every repository would copy whatever convention it finds.
A name is cheapest to fix before it ships in eighteen places.

Three conventions solve different parts of the problem. macOS names a tool
with one lowercase word for what it manages (`defaults`, `diskutil`).
systemd gives every manager the same verbs (`start`, `stop`, `status`).
PowerShell keeps a closed list of approved verbs, so a user can guess a
command they have never seen.

## Decision

### Grammar

`dot <domain> [<object>] <verb> [args] [flags]`: at most three words before
the arguments. A domain is one lowercase ASCII word of 2 to 8 letters,
singular, with no digits, hyphens or underscores (N1). Acronyms only where
they are the industry word: `ai`, `mcp`, `cli`, `ui`. Objects are singular
nouns declared in the plugin manifest (N3).

### Domains and repositories

Seventeen domains, listed in [`schemas/cli/domains.json`](https://github.com/sebastienrousseau/dotfiles/blob/main/schemas/cli/domains.json)
with their help group and one-line summary. Repository `dot-<domain>`
provides exactly `dot <domain>` and the entry binary `dot-<domain>` (N2).
The distro `dotfiles` and the infrastructure repositories (`.github`,
`plugin-template`, `homebrew-tap`, `scoop-bucket`) provide no command.
This renames two repositories from plan v2: the host `dot` becomes
`dot-cli` (matching the AUR package `dot-cli-git`), and `dot-secrets`
becomes `dot-secret`. All repositories live under the personal GitHub
account `sebastienrousseau`; signer identities are pinned to it.

### Verbs

A closed list of 37 verbs in [`schemas/cli/verbs.json`](https://github.com/sebastienrousseau/dotfiles/blob/main/schemas/cli/verbs.json)
(N4). Each has one meaning, one side-effect class (`read`, `change`, or
`any` for verbs that launch a process), a PowerShell approved verb, and the
words it replaces. There are no synonyms: `remove`, never `rm` or `delete`;
`list`, never `ls` (N6). Adding a verb needs a new ADR and a PowerShell
mapping.

A domain or object with no verb does the read-only thing: `show`, `list`,
`status`, the `select` picker, or the domain's TUI (N5). Anything that
changes the system needs an explicit verb.

### Built-ins and aliases

The host builds in only `dot help`, `dot version` and `dot cli` (N8).
`dot help <term>` searches. Aliases are of two kinds only (N7):

- Seven daily shortcuts: `dot apply`, `sync`, `diff`, `status` and `edit`
  (to `dot config …`), `dot update` (to `dot system update`) and `dot cd`
  (to `dot config path`, shipped as a shell function by dot-shell).
- Deprecated names, which work for one family release (about one week at
  the weekly cadence), print the new spelling once per shell session, and
  then exit 127 with a hint.

### Flags and exit codes

GNU long options with POSIX short options, listed in
[`schemas/cli/flags.json`](https://github.com/sebastienrousseau/dotfiles/blob/main/schemas/cli/flags.json) (N9). Family-wide
meanings never change: `-h/--help`, `-V/--version`, `-v/--verbose`,
`-q/--quiet`, `-y/--yes`, `-n/--dry-run`, `--json`, `--plain`,
`--no-color`, `--force`, `--no-motion`. This breaks `dot -v`, which prints
the version today; it becomes `--verbose` after one release of warnings.

Exit codes (N10): 0 ok, 1 warning or check failed, 2 critical, 64 usage
error, 75 temporary failure such as a held lock, 127 unknown command,
removed name or missing plugin, 130 interrupted.

### Windows

PowerShell cmdlets are generated as `<Verb>-Dot<Domain>[<Object>]` from the
verb map (N11): `dot ai list` becomes `Get-DotAi`, `dot secret key new`
becomes `New-DotSecretKey`. Where two verbs share a PowerShell verb, the
registry declares the rule: `list` and `show` are one `Get` cmdlet (`show`
takes `-Name`); `status` appends `Status` to the noun; `set` and `apply`,
and `start` and `serve`, never appear on the same object.

### Files, identifiers and output

- Paths (N12): config `$XDG_CONFIG_HOME/dot/<domain>.toml`, state
  `$XDG_STATE_HOME/dot/<domain>/`, cache `$XDG_CACHE_HOME/dot/<domain>/`;
  `%APPDATA%\dot\` on Windows; helpers in `libexec/dot/<domain>/`; man
  pages `dot(1)` and `dot-<domain>(1)`.
- Identifiers (N13): environment `DOT_<DOMAIN>_<NAME>`; schema ids
  `<domain>/<name>.v<N>`; Go modules `github.com/sebastienrousseau/dot-<domain>`;
  Homebrew formula and aqua id `dot-<domain>`; log source tag = domain.
- Output (N14): results on stdout, logs on stderr; `--json` with a
  versioned schema on every read command; no colour when piped, under
  `NO_COLOR` or with `TERM=dumb`; something printed within 100 ms.
- Configuration precedence (N15): flags, then `DOT_*` environment, then
  `$XDG_CONFIG_HOME/dot/<domain>.toml`, then the distro's defaults, then
  built-ins.
- Side-effect class (N16): every command declares `read`, `write` or
  `destructive`. The class drives help labels, confirmation, what
  `dot agent` allows in plan mode, and which commands become MCP tools
  (read only).
- Locking (N17): `write` and `destructive` commands take a per-domain lock
  in `$XDG_STATE_HOME/dot/<domain>/lock`, and a second run waits or exits 75
  with the holder's PID.

### Manifest v1

Each plugin declares its names in `dot-plugin.toml`, validated by
[`schemas/cli/manifest.v1.schema.json`](https://github.com/sebastienrousseau/dotfiles/blob/main/schemas/cli/manifest.v1.schema.json):
`domain`, `default`, `ps_noun`, `objects`, `commands` (each an optional
object, a verb, an effect and an optional `--json` output schema id) and
`aliases` (shortcut, deprecated with an `until` release, or removed).
[`schemas/cli/examples/dot-plugin.toml`](https://github.com/sebastienrousseau/dotfiles/blob/main/schemas/cli/examples/dot-plugin.toml)
shows the secret domain. The plugin host, trust and hook fields are
reserved in the schema and defined by the plan's P2 work.

### The Graphviz collision

Graphviz also installs `dot`. The family keeps the name because it already
ships. `dot doctor` warns when another `dot` comes first on `PATH`, the
Homebrew formula `dot-cli` notes `conflicts_with "graphviz"`, and `dot-cli`
is documented as an alternative entry point.

## Consequences

- Every one of today's 105 routes gets a new spelling (plan v3, command
  map). Old names keep working for one family release.
- Help, man pages, completions for five shells and PowerShell cmdlets can
  be generated from manifests, so no completion list is written by hand.
- Agents get one machine-readable command tree (`dot help --json`) whose
  side-effect classes match what `dot agent` and `dot mcp` enforce.
- `dot -v` changes meaning. Scripts that parse it must move to
  `dot --version` or `dot version`.

## Enforcement

| Step | Gate | State |
|------|------|-------|
| Registries and manifest schema | `tests/unit/dot-cli/test_naming_registry.py` in Core and delivery contracts | done |
| CLI-contract lint over manifests, routes, flags and exit codes | `tools/ci/check-cli-contract.py` in Core and delivery contracts; `tests/unit/dot-cli/test_cli_contract_lint.py` plants each violation | done; three runtime violations baselined until the alias table |
| Alias table from the command map | every route resolves; deprecated names warn; removed names exit 127 | pending |
| Help, man pages, completions and cmdlets generated from manifests | no hand-written completion list remains | pending |
| One update path, `dot system update` | a scheduled run exits 0 on macOS and Linux | pending |

Each domain declares its names in `plugins/<domain>/dot-plugin.toml`, and
every route in `lib/dot/data/routes.txt` has an alias there. Writing them
corrected spellings in the plan's command map that broke N3, N4 or N5:
`dot secret audit` is `dot secret check`, `dot secret get` is
`dot secret show`, `dot shell refresh` is `dot shell update` (a bare
object may not regenerate anything), `dot cli search` is
`dot cli list --available` beside `dot help <term>`, and the objects
`conflicts` and `metrics` are singular. `dot agent delegate` has no
approved verb and is left out until one is chosen. The runtime checks
(`-V`, `-v`, exit 127) fail today and are listed in
`tools/ci/cli-contract-baseline.txt`, which may only shrink.

Related: [ADR-004](ADR-004-cli-architecture.md) (CLI wrapper),
[ADR-016](ADR-016-plugin-trust-sandbox.md) (plugin trust),
[ADR-021](ADR-021-family-lockstep-version.md) (versioning),
[ADR-022](ADR-022-family-language-go.md) (language).
