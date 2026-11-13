# The development shell: the tools of the atom, until atom-workspace builds
# devShells.default (FY-0017, FY-0038).
{
  perSystem =
    { config, ... }:
    {
      devShells.default = config.devShells.flakeyard-workflows;
    };
}
