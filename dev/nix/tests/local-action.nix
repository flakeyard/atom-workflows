# actionlint checks the inputs of a local action in the check, as the hook
# does in the working tree: the check runs in a git repository.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      failure =
        pkgs.testers.testBuildFailure
          (fixture { name = "local-action"; }).checks.${system}.workflows;
    in
    {
      checks.test-local-action = pkgs.runCommand "test-local-action" { } ''
        log=${failure}/testBuildFailure.log
        cat "$log"
        grep -F 'input "greeting" is not defined in action "hello"' "$log"
        touch $out
      '';
    };
}
