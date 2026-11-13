# fixture: the flake of a project in dev/fixtures/<name> that imports the atom
# as consumers do, and module, the project's own settings. The atom gets this
# flake's git-hooks, as with follows, unless git-hooks is given.
{ inputs, root, ... }:
{
  _module.args.fixture =
    {
      name,
      git-hooks ? inputs.git-hooks,
      module ? { },
    }:
    inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          self = {
            outPath = root + "/dev/fixtures/${name}";
            inherit inputs;
          };
        };
      }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          ((import (root + "/flake.nix")).outputs { inherit git-hooks; }).flakeModules.default
          module
        ];
        perSystem.pre-commit.check.enable = false;
        # allSystems.<system> exposes the hooks to the tests.
        debug = true;
      };
}
