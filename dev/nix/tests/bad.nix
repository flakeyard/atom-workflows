# A project whose workflows fail both tools: the check fails and reports the
# findings of both.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      failure = pkgs.testers.testBuildFailure (fixture { name = "bad"; }).checks.${system}.workflows;
    in
    {
      checks.test-bad = pkgs.runCommand "test-bad" { } ''
        log=${failure}/testBuildFailure.log
        cat "$log"
        grep -F 'unknown Webhook event "pushh"' "$log"
        grep -F 'unpinned-uses' "$log"
        grep -F 'template-injection' "$log"
        touch $out
      '';
    };
}
