# A project whose workflows and actions pass: the check succeeds, also with
# the messages of actionlint that the atom ignores.
{ fixture, ... }:
{
  perSystem =
    { system, ... }:
    {
      checks.test-good = (fixture { name = "good"; }).checks.${system}.workflows;
    };
}
