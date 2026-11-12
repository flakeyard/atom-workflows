---
id: ADR-0001
title: Lint workflows and actions with actionlint and zizmor
status: accepted
date: 2026-11-12
supersedes: []
superseded_by: []
related: []
affects:
  ["flake.nix", "flake.lock", "nix/**", "config/**", "dev/**", "README.md"]
review_by:
---

## Context

atom-workflows is the first atom of step 8 of [FY-0022][fy-0022]
([FY-0038][fy-0038]): the flake-parts module that owns GitHub Actions workflow
and action files, with actionlint and zizmor ([FY-0017][fy-0017]). Decisions of
flakeyard require of it:

- [FY-0017][fy-0017]: inputs are exactly the upstream flakes whose modules the
  atom imports, under canonical names, checked against the consumer's input of
  the same name before the import. Upstream options are set with
  `lib.mkOverride 900`, tool packages come from the consumer's `pkgs`, the
  domain has one substitutable check without network access, work that needs the
  network is an app, and developer tools are `devShells.flakeyard-<atom>`. Tests
  live in `dev/` with their own lock and import the atom as consumers do.
- [FY-0037][fy-0037]: the atom ships flakeyard's configuration of each tool in
  `config/`; a project's file at the tool's standard root path replaces it
  wholly, is detected with `builtins.pathExists` and is passed by flag; the
  chosen file enters the check as a store path of its own.
- [FY-0038][fy-0038]: releases start at `v0.1.0` with the moving tag `v0`; the
  warning of the next major version lives in `nix/next-major.nix`; scheduled
  tests run through workflow-check; until atom-workspace, a consumer switches
  off `checks.pre-commit` itself.
- [FY-0030][fy-0030]: flakeyard's workflows reference their own repository with
  `$/<path>` and pin every other action by full commit SHA.

Experiments with actionlint 1.7.12 and zizmor 1.32.0 of `nixos-26.05`, and
git-hooks.nix at `204b6977`, showed:

- git-hooks.nix defines the hooks `actionlint` and `zizmor`, both with
  `files = "^.github/workflows/"` (an unescaped dot) and the upstream packages.
  zizmor also audits composite actions, `action.yml`.
- actionlint reports three messages about valid syntax it does not know: `$/`
  references of actions and of reusable workflows, and the key `queue` of
  `concurrency`. Its `-ignore` flag takes a regular expression matched against
  the message alone.
- actionlint checks the inputs of local actions only in a directory with `.git`;
  an empty `.git` directory is enough. A check in the Nix sandbox has none.
- zizmor 1.32.0 has 41 audits, listed in `support/zizmor.schema.json` of its
  source, which `pkgs.zizmor.src` contains. Four of them need the network:
  `impostor-commit`, `known-vulnerable-actions`, `ref-confusion` and
  `stale-action-refs`. zizmor discovers `.github/zizmor.yml`,
  `.github/zizmor.yaml`, `zizmor.yml` and `zizmor.yaml` at the root of a
  repository, and `--config` turns discovery off. It reads a token from
  `GH_TOKEN`.
- The workflows of action-flake-lock, action-shell-lib, image-devcontainer,
  workflow-check and workflow-release pass zizmor with every audit enabled,
  `--offline` and the persona `regular`.
- A dev flake that declares the atom as `path:..` fails the pin form rule of
  action-flake-lock, which exempts only relative paths inside the flake's
  directory.

## Decision

### Inputs and tools

The public flake has one input, `git-hooks` (cachix/git-hooks.nix); the atom has
no formatter, so it has no `treefmt-nix`. The atom fails evaluation with the
line `inputs.git-hooks.follows = "git-hooks";` when the consumer's `git-hooks`
has another store path.

The atom enables the upstream hooks `actionlint` and `zizmor` and owns them. It
sets their `package` to `pkgs.actionlint` and `pkgs.zizmor` of the consumer, and
their `files` and `args`, all with `lib.mkOverride 900`:

- `actionlint`: files `^\.github/workflows/`. Arguments: `-config-file` with the
  chosen file, `-shellcheck=` with shellcheck of the consumer's `pkgs`, which
  actionlint runs for `run:` blocks as a dependency ([FY-0037][fy-0037]),
  `-pyflakes=` (off), and one `-ignore` per known false positive, each anchored
  to the whole message. Flags apply with a project's own file too.
- `zizmor`: files
  `^\.github/workflows/|^action\.ya?ml$|^\.github/actions/.*/action\.ya?ml$`.
  Arguments: `--offline`, `--no-progress`, `--persona=` with the option
  `workflows.zizmor.persona` of `perSystem` (`regular`, `pedantic` or `auditor`;
  default `regular`) and `--config` with the chosen file. No minimum severity or
  confidence.

### Configuration

`config/actionlint.yaml` and `config/zizmor.yml` hold flakeyard's configuration
under the tools' own names, so that a project can copy them unchanged. They
write out every value the tool would otherwise default, with a comment on why:

- actionlint: no self-hosted runner labels, `config-variables: null` (no check
  of the names in `vars`, which every project defines), no `paths`.
- zizmor: all 41 audits with `disable: false`, grouped by concern;
  `unpinned-uses` with the policy `"*": hash-pin`, zizmor's default written out
  against a change upstream; `forbidden-uses` without a list, because allowlists
  belong to an organization and flakeyard enforces its own in the organization's
  settings; `dependabot-cooldown` with its default of 7 days. No ignores and no
  remapped severities.

The project's file replaces the default when it exists at
`.github/actionlint.yaml` or `.github/actionlint.yml`, and at
`.github/zizmor.yml`, `.github/zizmor.yaml`, `zizmor.yml` or `zizmor.yaml`, the
first one in this order. The atom detects it with `builtins.pathExists` on the
consumer's `self`, which for a git flake holds only tracked files, and copies
the chosen file with `builtins.path`.

### Check, app and shell

`checks.workflows` runs both hooks, with their `entry` and `args`, over a store
path that holds only the files the hooks select (their `files` and the `yaml`
type), and passes each hook the paths it selects. It runs in a copy with an
empty `.git`, so actionlint checks local actions as the hook does in the working
tree, runs each enabled hook even when another fails, and has no network access.
It stays substitutable.

`apps.workflows-online` runs the hook `zizmor` without `--offline` over the same
files, so the four online audits run too. It needs `GH_TOKEN`, and writes
annotations (`--format github`) when `GITHUB_ACTIONS` is set.

`devShells.flakeyard-workflows` holds actionlint, zizmor and shellcheck.

### Next major version

While `nix/next-major.nix` exists, `checks.workflows` and
`devShells.flakeyard-workflows` warn with `lib.warn` of the consumer's nixpkgs:
the version, the end of support 6 months after it, and the link to the migration
guide the file names ([FY-0016][fy-0016], [FY-0038][fy-0038]).

### Tests

`dev/flake.nix` imports the atom from the flake's own outputs called with the
dev flake's `git-hooks`, which is what `follows` gives a consumer, and lints
this repository with it. Its checks evaluate on x86_64-linux and aarch64-linux:
fixture projects that pass, that fail both tools, that bring their own
configuration files, a test that fails once actionlint stops reporting one of
the ignored messages, a test of the follows error, of the next-major warning,
and a test that `config/zizmor.yml` is valid against zizmor's schema and lists
every audit in it.

## Constraints

- The public flake MUST declare only the input `git-hooks`, and MUST fail
  evaluation with the exact follows line when the consumer's `git-hooks` has
  another store path.
- The atom MUST set the hooks `actionlint` and `zizmor` only with
  `lib.mkOverride 900`, with packages of the consumer's `pkgs`.
- The atom MUST pass the chosen configuration file by `-config-file` and
  `--config` to every run of the tools, and MUST NOT let them discover one.
- `-ignore` patterns MUST be anchored to the whole message of a known false
  positive, and a test MUST fail when actionlint no longer reports it.
- `config/zizmor.yml` MUST list every audit of the zizmor in the consumer's
  nixpkgs, and a test MUST check this against zizmor's schema.
- `checks.workflows` MUST run `--offline` and MUST use the same `entry` and
  `args` as the hooks; the app MUST differ only by not passing `--offline` and
  by the output format.
- The check MUST depend only on the files of the domain and the chosen
  configuration files.
- Everything listed in the "Public API" of the README is the public API
  ([FY-0017][fy-0017], [FY-0024][fy-0024]).

## Consequences

- (+) A project gets the same findings in the git hook, in `nix flake check` and
  in CI, with flakeyard's configuration or its own.
- (+) A change outside workflows and actions keeps `checks.workflows` cached.
- (+) New audits of zizmor and fixed messages of actionlint are noticed by the
  scheduled tests, not by surprise.
- (−) Online audits do not run in `nix flake check`; a project runs the app in
  CI with a token.
- (−) Composite actions outside `.github/actions/` and the root are not audited.
- (−) Until actionlint knows `$/` and `queue`, the atom carries three ignore
  patterns, also for projects that use neither.
- (±) A project file that is not tracked by git is seen by the tools in the
  working tree but not by the atom.

## Alternatives considered

- **treefmt-nix as a second input.** The atom has no formatter.
- **The tools' own discovery of configuration files.** Rejected by FY-0037: the
  check in the sandbox would ignore a project's file.
- **`paths` of `actionlint.yaml` for the ignores.** A project's file would drop
  them.
- **Online audits in the check.** Checks run without network access (FY-0017).
- **The aggregated `checks.pre-commit` of git-hooks.nix.** It depends on the
  whole source of the project (FY-0017).
- **`path:..` as the atom's input in `dev/flake.nix`.** Fails the pin form rule
  of action-flake-lock.

[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0030]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0030-actions-workflows-and-release-bot.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
