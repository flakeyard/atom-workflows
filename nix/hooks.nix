# The hooks actionlint and zizmor of git-hooks.nix, with the configuration
# that the project chose (FY-0037). Their files, package and arguments are the
# single definition that the check and the app also run.
{ root }:
{ flake-parts-lib, self, ... }:
{
  _file = ./hooks.nix;

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { lib, ... }:
    {
      options.workflows.zizmor.persona = lib.mkOption {
        type = lib.types.enum [
          "regular"
          "pedantic"
          "auditor"
        ];
        default = "regular";
        description = "The persona of zizmor, which decides the findings it reports.";
      };
    }
  );

  config.perSystem =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # The project's file at the first standard path of the tool, else the
      # default of the atom; either one as a store path of its own.
      chosen =
        default: paths:
        let
          found = lib.findFirst (path: builtins.pathExists (self.outPath + "/${path}")) null paths;
        in
        if found == null then
          builtins.path {
            path = root + "/config/${default}";
            name = default;
          }
        else
          builtins.path {
            path = self.outPath + "/${found}";
            name = baseNameOf found;
          };
      # The standard paths that actionlint and zizmor discover.
      actionlintConfig = chosen "actionlint.yaml" [
        ".github/actionlint.yaml"
        ".github/actionlint.yml"
      ];
      zizmorConfig = chosen "zizmor.yml" [
        ".github/zizmor.yml"
        ".github/zizmor.yaml"
        "zizmor.yml"
        "zizmor.yaml"
      ];
      # Messages of actionlint 1.7.12 about valid syntax it does not know:
      # $/ references of the same repository (FY-0030) and the queue of a
      # concurrency group. Anchored to the whole message, so that nothing
      # else is ignored; a test fails once actionlint stops reporting one.
      ignores = [
        ''^specifying action "\$/[^"]*" in invalid format because ref is missing\. available formats are "\{owner\}/\{repo\}@\{ref\}" or "\{owner\}/\{repo\}/\{path\}@\{ref\}"$''
        ''^reusable workflow call "\$/[^"]*" at "uses" is not following the format "owner/repo/path/to/workflow\.yml@ref" nor "\./path/to/workflow\.yml"\. see https://docs\.github\.com/en/actions/learn-github-actions/reusing-workflows for more details$''
        ''^unexpected key "queue" for "concurrency" section\. expected one of "cancel-in-progress", "group"$''
      ];
    in
    {
      pre-commit.settings.hooks = {
        actionlint = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.actionlint;
          files = lib.mkOverride 900 ''^\.github/workflows/'';
          args = lib.mkOverride 900 (
            [
              "-config-file"
              "${actionlintConfig}"
              # Run by actionlint for run steps: a dependency, not a tool of
              # the atom (FY-0037).
              "-shellcheck=${lib.getExe pkgs.shellcheck}"
              # Off: a linter of another domain, which the atom does not own.
              "-pyflakes="
            ]
            ++ lib.concatMap (ignore: [
              "-ignore"
              ignore
            ]) ignores
          );
        };
        zizmor = {
          enable = lib.mkOverride 900 true;
          package = lib.mkOverride 900 pkgs.zizmor;
          # Workflows and composite actions.
          files = lib.mkOverride 900 ''^\.github/workflows/|^action\.ya?ml$|^\.github/actions/.*/action\.ya?ml$'';
          args = lib.mkOverride 900 [
            # The audits that need the network run in the app
            # workflows-online (FY-0017).
            "--offline"
            # Logs without progress bars, in the check and in git hooks.
            "--no-progress"
            "--persona=${config.workflows.zizmor.persona}"
            "--config"
            "${zizmorConfig}"
          ];
        };
      };
    };
}
