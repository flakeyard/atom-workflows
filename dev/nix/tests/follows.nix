# A consumer that locks git-hooks.nix a second time fails at evaluation with
# the follows line to add (FY-0017).
{ testing, ... }:
{
  perSystem = testing.follows {
    output = [
      "checks"
      "workflows"
    ];
    # Restated: the text is the interface (FY-0035).
    messages.git-hooks = ''
      atom-workflows: input 'git-hooks' is locked twice; add to input atom-workflows:
        inputs.git-hooks.follows = "git-hooks";'';
  };
}
