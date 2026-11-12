# checks.workflows: the hooks actionlint and zizmor, with their arguments,
# over the files of the domain, without network access (FY-0017).
{ self, ... }:
{
  _file = ./checks.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit.settings) hooks;
      domain = import ./files.nix { inherit lib self hooks; };
      warning = import ./warning.nix {
        inherit lib;
        file = ./next-major.nix;
      };
      # A hook over the files it selects; a failure fails the check after
      # every hook has run.
      run =
        hook:
        let
          files = domain.of hook;
        in
        lib.optionalString (hook.enable && files != [ ]) ''
          ${hook.entry} ${lib.escapeShellArgs (hook.args ++ files)} || status=1
        '';
    in
    {
      checks.workflows = warning (
        pkgs.runCommand "workflows" { } ''
          cp -r --no-preserve=mode ${domain.src} work
          cd work
          # actionlint checks the inputs of local actions only in a git
          # repository, like the hook in the working tree.
          mkdir .git
          export HOME=$TMPDIR
          status=0
          ${run hooks.actionlint}
          ${run hooks.zizmor}
          [[ $status == 0 ]] && touch $out
        ''
      );
    };
}
