# The configuration files (FY-0037): the project's file at a standard path
# replaces the default of the atom, and the chosen file is an input of the
# check as a store path of its own.
{
  facts,
  fixture,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      project = name: (fixture { inherit name; }).allSystems.${system};
      # The store path of a file, as text to look for.
      stored =
        path:
        builtins.unsafeDiscardStringContext "${builtins.path {
          inherit path;
          name = baseNameOf path;
        }}";
      # The arguments of both hooks and the configuration of pre-commit in the
      # check.
      uses =
        name: path:
        let
          inherit (project name) checks pre-commit;
          inherit (pre-commit.settings) hooks;
        in
        lib.elem (stored path) (hooks.actionlint.args ++ hooks.zizmor.args)
        && lib.hasInfix (stored path) (builtins.toJSON checks.workflows.config.rawConfig);
      own = root + "/dev/fixtures/project-config/.github";
      default = root + "/config";
    in
    {
      checks.test-configs = facts pkgs "test-configs" {
        "the project's actionlint.yaml is used" = uses "project-config" (own + "/actionlint.yaml");
        "the project's zizmor.yml is used" = uses "project-config" (own + "/zizmor.yml");
        "the default actionlint.yaml is not used" = !uses "project-config" (default + "/actionlint.yaml");
        "the default zizmor.yml is not used" = !uses "project-config" (default + "/zizmor.yml");
        "without a file, the default actionlint.yaml is used" = uses "good" (default + "/actionlint.yaml");
        "without a file, the default zizmor.yml is used" = uses "good" (default + "/zizmor.yml");
      };
      # The workflows of the project pass only with the project's files.
      checks.test-configs-project = (project "project-config").checks.workflows;
    };
}
