# The files of the domain: the project's files that the `files` pattern of the
# hook actionlint or zizmor matches, copied to a store path of their own, so
# that a change elsewhere keeps the check cached (FY-0017). The filter is
# coarse: in the check, pre-commit selects among them by `files`, `types` and
# `excludes`.
{
  lib,
  self,
  hooks,
}:
let
  domain = [
    hooks.actionlint
    hooks.zizmor
  ];
  relative = path: lib.removePrefix "${toString self.outPath}/" (toString path);
  # pre-commit searches the pattern in the relative path.
  matches = hook: path: builtins.match ".*(${hook.files}).*" path != null;
  # Read from the project's source, never from a store path made during
  # evaluation, which a store may not have.
  files = lib.filter (path: lib.any (hook: matches hook path) domain) (
    map relative (lib.filesystem.listFilesRecursive self.outPath)
  );
  # The files and only the directories that hold them.
  src = builtins.path {
    name = "workflows";
    path = self.outPath;
    filter =
      path: type:
      let
        file = relative path;
      in
      if type == "directory" then lib.any (lib.hasPrefix "${file}/") files else lib.elem file files;
  };
in
{
  inherit src;
  # The paths that the app passes to a hook, relative to src; types =
  # [ "yaml" ] of both hooks selects these extensions.
  of =
    hook:
    lib.filter (
      path: matches hook path && (lib.hasSuffix ".yml" path || lib.hasSuffix ".yaml" path)
    ) files;
}
