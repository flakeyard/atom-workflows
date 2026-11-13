# checks.workflows: the hooks actionlint and zizmor, as the project's
# configuration holds them, without network access (FY-0017). Built with
# lib.<system>.run of git-hooks.nix from only these hooks and the project's
# global excludes, so pre-commit selects the files by `files`, `types` and
# `excludes` as the installed hook does.
{ git-hooks }:
{ self, ... }:
{
  _file = ./checks.nix;

  config.perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit) settings;
      domain = import ./files.nix {
        inherit lib self;
        inherit (settings) hooks;
      };
      warning = import ./warning.nix {
        inherit lib;
        file = ./next-major.nix;
      };
      # Every option of the project's hook; raw is computed from the others.
      hook = name: removeAttrs settings.hooks.${name} [ "raw" ];
    in
    {
      # run does git init, so actionlint checks the inputs of local actions
      # as the hook does in the working tree.
      checks.workflows = warning (
        git-hooks.lib.${system}.run {
          inherit (domain) src;
          hooks = lib.genAttrs [ "actionlint" "zizmor" ] hook;
          inherit (settings) excludes package gitPackage;
        }
      );
    };
}
