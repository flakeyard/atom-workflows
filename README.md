# atom-workflows

A flake-parts module that lints GitHub Actions workflows and actions with
actionlint and zizmor, as git hooks, as the check `checks.workflows` and, for
the audits that need the network, as the app `workflows-online`
([FY-0017][fy-0017], [ADR-0001][adr-0001]).

It checks:

- with actionlint, every workflow under `.github/workflows/`: syntax,
  expressions, events, inputs of actions and reusable workflows, and the `run:`
  blocks with shellcheck;
- with zizmor, the workflows and the composite actions `action.yml` at the root
  and under `.github/actions/`: pinning, injection, credentials, permissions,
  triggers and conditions.

## Inputs

The atom has one input, `git-hooks`, which the project makes it share with
`follows` ([FY-0017][fy-0017]). While the atom is `0.y.z`, only flakeyard's own
repositories use it, in the form of [FY-0016][fy-0016]:

```nix
{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=<commit>&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atom-workflows = {
      url = "git+https://github.com/flakeyard/atom-workflows?ref=v0&rev=<commit>&shallow=1";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [ inputs.atom-workflows.flakeModules.default ];
      # Until the project adopts atom-workspace (FY-0038).
      perSystem.pre-commit.check.enable = false;
    };
}
```

Without the `follows` line, evaluation fails with:

```text
atom-workflows: input 'git-hooks' is locked twice; add to input atom-workflows:
  inputs.git-hooks.follows = "git-hooks";
```

The line `perSystem.pre-commit.check.enable = false;` switches off the
aggregated `checks.pre-commit` of git-hooks.nix, which depends on the whole
source of the project. atom-workspace will switch it off; until then the project
does ([FY-0038][fy-0038]).

## Files it reads

From the project's source, which for a git flake holds only tracked files:

- the workflows, `.github/workflows/*.yml` and `*.yaml`, also in subdirectories;
- the composite actions `action.yml` and `action.yaml` at the root and
  `.github/actions/**/action.yml` and `action.yaml`;
- the configuration files at the standard paths of the table below.

## Tools and configuration

Each tool gets the configuration file the project chose: the project's file at
the tool's standard path at the root, else the default of the atom in
[`config/`](config). The project's file replaces the default wholly; nothing is
merged. The atom passes the chosen file by flag and never lets a tool discover
one ([FY-0037][fy-0037]).

| Tool       | Standard path             | Default      | Project's file |
| ---------- | ------------------------- | ------------ | -------------- |
| actionlint | `.github/actionlint.yaml` | [config][al] | replaces it    |
| zizmor     | `.github/zizmor.yml`      | [config][zz] | replaces it    |
| shellcheck | none                      | none         | not read       |

- actionlint also finds `.github/actionlint.yml`, and zizmor
  `.github/zizmor.yaml`, `zizmor.yml` and `zizmor.yaml`; the first path found,
  in the order listed, wins.
- actionlint always gets `-config-file` with the chosen file,
  `-shellcheck=<shellcheck>` and `-pyflakes=` (off), and four `-ignore`
  patterns.
- zizmor always gets `--config` with the chosen file, `--no-progress`,
  `--persona=<persona>` and, except in the app `workflows-online`, `--offline`.
- shellcheck is run by actionlint for `run:` blocks, as a dependency from the
  project's nixpkgs; actionlint passes it no configuration, and the atom owns no
  configuration of it.

The `-ignore` patterns drop four messages of actionlint about valid syntax it
does not know yet, each matched against the whole message: `$/` references of
actions and of reusable workflows, the key `queue` of `concurrency`, and the
GitHub-hosted runner labels `ubuntu-26.04` and `ubuntu-26.04-arm`. They are
flags, so they apply with a project's file too. A test of the atom fails once
actionlint stops reporting one of them.

To replace a default, copy it from [`config/`](config) to a standard path,
commit it and edit it. Since the atom reads only tracked files, an untracked
file is seen by the tool in the working tree but not by the atom.

## Options

- `perSystem.workflows.zizmor.persona`: the persona of zizmor, `regular`
  (default), `pedantic` or `auditor`, in the check, the hook and the app.

The hooks `actionlint` and `zizmor` of git-hooks.nix are set with
`lib.mkOverride 900`, so a plain definition of the project, such as
`perSystem.pre-commit.settings.hooks.zizmor.args = [ ... ];`, replaces a value
of the atom without `mkForce`. The check and the app run the hooks' `entry` and
`args`, so such a definition changes them too. The check also honours the hooks'
other options and the project's global `perSystem.pre-commit.settings.excludes`:
pre-commit selects the files in the check as the installed hook does.

## Outputs

- `flakeModules.default`: the module. It adds to every system:
  - the hooks `actionlint` and `zizmor`, enabled, with the packages of the
    project's nixpkgs;
  - `checks.workflows`: both hooks, run by pre-commit through `lib.<system>.run`
    of git-hooks.nix with the project's global excludes, over the files of the
    domain, without network access. It depends only on the files that the hooks'
    `files` patterns match and the chosen configuration files, so other changes
    keep it cached and substitutable;
  - `apps.workflows-online`: zizmor with the same configuration and persona,
    without `--offline`, so that the audits that need the network run too. It
    reads a GitHub token from `GH_TOKEN` and fails without one, and writes
    annotations when `GITHUB_ACTIONS` is set:

    ```sh
    GH_TOKEN=$(gh auth token) nix run .#workflows-online
    ```

  - `devShells.flakeyard-workflows`: actionlint, zizmor and shellcheck, which
    atom-workspace joins into `devShells.default`.

Supported systems are `x86_64-linux` and `aarch64-linux`.

## Supported upstream revisions

The oldest supported revisions are those the tests run with: git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`, with actionlint 1.7.12 and zizmor
1.32.0. An older zizmor rejects audits that
[`config/zizmor.yml`](config/zizmor.yml) lists.

## Public API

Releases follow [semantic versioning][versioning] ([FY-0024][fy-0024]). The
public API is the input `git-hooks`, `flakeModules.default`, the hooks
`actionlint` and `zizmor`, the values the atom sets whose change fails a project
that passed before (the default configurations, the flags and the `files` of the
hooks), the files it reads, the option `workflows.zizmor.persona`, the app
`workflows-online` with `GH_TOKEN` and `GITHUB_ACTIONS`, the outputs
`checks.workflows` and `devShells.flakeyard-workflows`, the supported systems
and the oldest supported upstream revisions. Versions of actionlint and zizmor
come from the project's nixpkgs and are not part of it.

The last minor release before a major one contains `nix/next-major.nix`; while
it exists, the check and the shell warn at evaluation that the next major
version is coming and where its migration guide is ([FY-0038][fy-0038]).

## Develop in the container

Open the repository in the flakeyard dev container: the editor reads
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json), and
`direnv` loads the shell of [`dev/flake.nix`](dev/flake.nix) through
[`.envrc`](.envrc) ([FY-0012][fy-0012]). With Nix on the host, `direnv allow` or
`nix develop ./dev` gives the same shell.

The public [`flake.nix`](flake.nix) holds only the input and the module
([FY-0017][fy-0017]). [`dev/flake.nix`](dev/flake.nix), with its own lock,
imports the atom as consumers do and holds the tests:

- `workflows`: the atom's check of this repository;
- `test-good`, `test-bad`, `test-configs-project`: the check of the fixture
  projects in [`dev/fixtures`](dev/fixtures), which pass, fail both tools and
  pass only with their own configuration files;
- `test-excluded`, `test-not-excluded`: the project's global excludes skip a
  failing workflow in the check, and other excludes do not;
- `test-local-action`: actionlint checks the inputs of a local action in the
  check;
- `test-configs`: the project's files replace the defaults in the hooks and in
  the check;
- `test-ignores`: actionlint still reports each message the atom ignores;
- `test-follows`: the error for a missing `follows`;
- `test-next-major`: the warning of the next major version;
- `test-zizmor-audits`: [`config/zizmor.yml`](config/zizmor.yml) is valid and
  lists every audit of zizmor.

Run the same commands as CI:

```sh
nix flake check --no-update-lock-file ./dev
nix flake check --no-update-lock-file --no-build --all-systems ./dev
```

CI runs [`test.yaml`](.github/workflows/test.yaml), which calls
[workflow-check][workflow-check] with `./dev`: it checks `dev/flake.lock`,
builds every check on x86_64 and arm64 runners, checks the pull request title
and `renovate.json`, and reports `check / required` ([FY-0034][fy-0034]).
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard, and
[`release.yaml`](.github/workflows/release.yaml) releases the repository with
[workflow-release][workflow-release].

Before a pull request, also run prettier, markdownlint, typos and `reuse lint`;
the atoms that will provide them are not released yet ([FY-0038][fy-0038]).

## License

[MIT](LICENSE).

[al]: config/actionlint.yaml
[zz]: config/zizmor.yml
[adr-0001]:
  docs/adr/records/0001-lint-workflows-and-actions-with-actionlint-and-zizmor.md
[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0037]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0037-atoms-ship-default-configs-that-projects-replace.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
