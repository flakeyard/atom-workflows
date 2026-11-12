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
  relative = base: path: lib.removePrefix "${toString base}/" (toString path);
  # pre-commit searches files in the relative path; types = [ "yaml" ] of
  # both hooks selects these extensions.
  selects =
    hook: path:
    builtins.match ".*(${hook.files}).*" path != null
    && (lib.hasSuffix ".yml" path || lib.hasSuffix ".yaml" path);
  # Every directory and the files of the domain.
  selected = builtins.path {
    name = "workflows-files";
    path = self.outPath;
    filter =
      path: type: type == "directory" || lib.any (hook: selects hook (relative self.outPath path)) domain;
  };
  files = map (relative selected) (lib.filesystem.listFilesRecursive selected);
  # The same files without the directories that hold none of them.
  src = builtins.path {
    name = "workflows";
    path = selected;
    filter =
      path: type: type != "directory" || lib.any (lib.hasPrefix "${relative selected path}/") files;
  };
in
{
  inherit src;
  # The paths that a hook selects, relative to src.
  of = hook: lib.filter (selects hook) files;
}
