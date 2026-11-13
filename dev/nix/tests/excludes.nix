# The project's global excludes, pre-commit.settings.excludes, apply to the
# check as to the hook: the failing workflows of dev/fixtures/bad pass once
# excluded, and still fail when the excludes name other files.
{ fixture, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      excluding =
        excludes:
        (fixture {
          name = "bad";
          module.perSystem.pre-commit.settings = { inherit excludes; };
        }).checks.${system}.workflows;
      failure = pkgs.testers.testBuildFailure (excluding [ ''^\.github/workflows/other\.yaml$'' ]);
    in
    {
      checks.test-excluded = excluding [ ''^\.github/workflows/test\.yaml$'' ];
      checks.test-not-excluded = pkgs.runCommand "test-not-excluded" { } ''
        log=${failure}/testBuildFailure.log
        cat "$log"
        grep -F 'unknown Webhook event "pushh"' "$log"
        grep -F 'unpinned-uses' "$log"
        touch $out
      '';
    };
}
