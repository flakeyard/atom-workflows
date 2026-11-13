# The messages that the hook actionlint ignores are still reported by
# actionlint: without any one of its -ignore flags, the workflows of the
# project dev/fixtures/good fail. Once actionlint stops reporting one, this
# test fails and the flag goes away.
{ fixture, root, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      hook = (fixture { name = "good"; }).allSystems.${system}.pre-commit.settings.hooks.actionlint;
      # The arguments of the hook split into the patterns of -ignore and the
      # other flags.
      split =
        args:
        if args == [ ] then
          {
            flags = [ ];
            ignores = [ ];
          }
        else if lib.head args == "-ignore" then
          let
            rest = split (lib.drop 2 args);
          in
          rest // { ignores = [ (lib.elemAt args 1) ] ++ rest.ignores; }
        else
          let
            rest = split (lib.tail args);
          in
          rest // { flags = [ (lib.head args) ] ++ rest.flags; };
      inherit (split hook.args) flags ignores;
      without =
        ignore:
        flags
        ++ lib.concatMap (other: [
          "-ignore"
          other
        ]) (lib.remove ignore ignores);
    in
    {
      checks.test-ignores = pkgs.runCommand "test-ignores" { } ''
        cp -r --no-preserve=mode ${root + "/dev/fixtures/good"} work
        cd work
        mkdir .git
        [[ ${toString (lib.length ignores)} == 3 ]]
        status=0
        ${lib.concatMapStrings (ignore: ''
          if ${hook.entry} ${lib.escapeShellArgs (without ignore)} .github/workflows/*.yaml; then
            echo "actionlint no longer reports what this pattern ignores:" ${lib.escapeShellArg ignore}
            status=1
          fi
        '') ignores}
        [[ $status == 0 ]] && touch $out
      '';
    };
}
