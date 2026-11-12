# devShells.flakeyard-workflows: the tools of the domain for people
# (FY-0017); atom-workspace joins it into devShells.default.
{
  _file = ./shell.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings) hooks;
      warning = import ./warning.nix {
        inherit (pkgs) lib;
        file = ./next-major.nix;
      };
    in
    {
      devShells.flakeyard-workflows = warning (
        pkgs.mkShellNoCC {
          packages = [
            hooks.actionlint.package
            hooks.zizmor.package
            pkgs.shellcheck
          ];
        }
      );
    };
}
