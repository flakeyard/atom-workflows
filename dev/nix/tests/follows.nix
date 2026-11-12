# A consumer that locks git-hooks.nix a second time fails at evaluation with
# the follows line to add (FY-0017).
{
  facts,
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      # git-hooks.nix under another store path, as the atom's own lock gives
      # it without follows.
      other = inputs.git-hooks // {
        outPath = "/nix/store/00000000000000000000000000000000-source";
      };
      message = import (root + "/nix/follows.nix") {
        name = "git-hooks";
        atom = other;
        consumer = inputs.git-hooks;
      };
      evaluated =
        git-hooks:
        builtins.tryEval
          (fixture {
            inherit git-hooks;
            name = "good";
          }).checks.${system}.workflows.drvPath;
    in
    {
      checks.test-follows = facts pkgs "test-follows" {
        "the same git-hooks evaluates" = (evaluated inputs.git-hooks).success;
        "another git-hooks fails" = !(evaluated other).success;
        # Restated: the text is the interface (FY-0035).
        "the error names the follows line" =
          message == ''
            atom-workflows: input 'git-hooks' is locked twice; add to input atom-workflows:
              inputs.git-hooks.follows = "git-hooks";'';
      };
    };
}
