# The files of the domain: what the hooks actionlint and zizmor select in the
# project's source, copied to a store path of their own, so that a change
# elsewhere keeps the check cached (FY-0017).
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
  # pre-commit searches files in the relative path; types = [ "yaml" ] of
  # both hooks selects these extensions.
  selects =
    hook: path:
    builtins.match ".*(${hook.files}).*" path != null
    && (lib.hasSuffix ".yml" path || lib.hasSuffix ".yaml" path);
  # Read from the project's source, never from a store path made during
  # evaluation, which a store may not have.
  files = lib.filter (path: lib.any (hook: selects hook path) domain) (
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
  # The paths that a hook selects, relative to src.
  of = hook: lib.filter (selects hook) files;
}
