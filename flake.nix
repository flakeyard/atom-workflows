{
  # The only input (FY-0017): consumers make the atom use their copy with
  # inputs.git-hooks.follows = "git-hooks";
  inputs.git-hooks.url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=204b6977e00caac19e2313015a598543ca7be150&shallow=1";

  outputs = inputs: { flakeModules.default = import ./nix inputs; };
}
