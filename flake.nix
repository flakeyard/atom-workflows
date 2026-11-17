{
  # The upstream input (FY-0017): consumers make the atom use their copy with
  # inputs.git-hooks.follows = "git-hooks";
  # lib-atom is pinned by the atom in its own flake.lock; consumers neither
  # declare nor follow it (FY-0040).
  inputs = {
    git-hooks.url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=204b6977e00caac19e2313015a598543ca7be150&shallow=1";
    lib-atom.url = "git+https://github.com/flakeyard/lib-atom?ref=v0&rev=f2c83b7399315afb477abba1e112bca107f0b345&shallow=1";
  };

  outputs = inputs: { flakeModules.default = import ./nix inputs; };
}
