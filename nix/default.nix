# The root module of atom-workflows (FY-0017). It fails when the consumer
# locks git-hooks.nix a second time, imports the module of git-hooks.nix and
# the atom's modules. The atom's inputs and the root of the repository reach
# the other files only as function arguments.
atomInputs:
{ inputs, ... }:
let
  root = ./..;
  # The functions that atoms share, of the revision the atom pins (FY-0040).
  shared = atomInputs.lib-atom.lib;
  upstream = shared.upstream {
    atom = "atom-workflows";
    own = atomInputs;
    consumer = inputs;
  };
  # The warning of the next major version, with lib of the consumer's nixpkgs.
  warning =
    lib:
    shared.warning {
      inherit lib;
      atom = "atom-workflows";
      inherit root;
    };
  # The files of the domain, which the check and the app share (FY-0017), from
  # lib of the consumer's nixpkgs and the hooks as the project's configuration
  # holds them.
  domain =
    {
      lib,
      self,
      hooks,
    }:
    shared.domain
      {
        inherit lib;
        project = self.outPath;
      }
      {
        name = "workflows";
        hooks = [
          hooks.actionlint
          hooks.zizmor
        ];
      };
in
{
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    (upstream "git-hooks" atomInputs.git-hooks.flakeModule)
    (import ./hooks.nix { inherit root shared; })
    (import ./checks.nix {
      inherit (atomInputs) git-hooks;
      inherit domain warning;
    })
    (import ./apps.nix { inherit domain; })
    (import ./shell.nix { inherit warning; })
  ];
}
