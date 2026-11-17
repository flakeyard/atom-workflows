# apps.workflows-online: zizmor with the audits that need the network, which
# the check cannot run (FY-0017). It runs the hook zizmor without --offline,
# over the files of the domain.
{ domain }:
{ self, ... }:
{
  _file = ./apps.nix;

  config.perSystem =
    { config, pkgs, ... }:
    let
      inherit (pkgs) lib;
      inherit (config.pre-commit.settings.hooks) zizmor;
      # The files of the domain, as checks.workflows has them.
      workflows = domain {
        inherit lib self;
        inherit (config.pre-commit.settings) hooks;
      };
      # The paths that the app passes to zizmor, relative to src; its types =
      # [ "yaml" ] selects these extensions.
      files = lib.filter (path: lib.hasSuffix ".yml" path || lib.hasSuffix ".yaml" path) (
        workflows.of zizmor
      );
      online = pkgs.writeShellApplication {
        name = "workflows-online";
        text = ''
          if [[ -z ''${GH_TOKEN:-} ]]; then
            echo "workflows-online: GH_TOKEN is empty; the online audits of zizmor need a GitHub token." >&2
            exit 1
          fi
          format=plain
          if [[ -n ''${GITHUB_ACTIONS:-} ]]; then
            format=github
          fi
        ''
        + (
          if files == [ ] then
            ''
              echo "workflows-online: no workflows or actions to audit."
            ''
          else
            ''
              # Paths relative to the root of the project, also in annotations.
              cd ${workflows.src}
              exec ${zizmor.entry} ${lib.escapeShellArgs (lib.remove "--offline" zizmor.args)} --format "$format" ${lib.escapeShellArgs files}
            ''
        );
      };
    in
    {
      apps.workflows-online = {
        type = "app";
        program = lib.getExe online;
        meta.description = "Audit workflows and actions with the online audits of zizmor.";
      };
    };
}
