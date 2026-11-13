# The error for an upstream flake that the consumer locks a second time
# (FY-0017), or null. Only store paths are compared; nothing is imported from
# the consumer's input.
{
  name,
  atom,
  consumer,
}:
if consumer == null || consumer.outPath == atom.outPath then
  null
else
  ''
    atom-workflows: input '${name}' is locked twice; add to input atom-workflows:
      inputs.${name}.follows = "${name}";''
