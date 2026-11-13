# config/zizmor.yml is valid for the zizmor that the atom runs and lists every
# audit of it: a new audit of zizmor, or a typo, fails.
{ root, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    let
      inherit (config.pre-commit.settings.hooks.zizmor) package;
    in
    {
      checks.test-zizmor-audits =
        pkgs.runCommand "test-zizmor-audits"
          {
            nativeBuildInputs = [
              pkgs.check-jsonschema
              pkgs.jq
            ];
          }
          ''
            jq '.required = ["rules"]
              | .definitions.RulesConfig.required = (.definitions.RulesConfig.properties | keys)' \
              ${package.src}/support/zizmor.schema.json >schema.json
            check-jsonschema --schemafile schema.json ${root + "/config/zizmor.yml"}
            touch $out
          '';
    };
}
