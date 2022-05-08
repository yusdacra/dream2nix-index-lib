{
  dream2nix,
  lib,
  ilib,
  system,
  ...
}: let
  l = lib // builtins;

  d2n = dream2nix.lib.${system};
in
  # tree: a source tree prepared with `dream2nix`'s `prepareSourceTree`.
  # this should be the source tree of a generated index directory.
  {tree}: let
    locksTree =
      tree.directories."locks"
      or {
        files = {};
        directories = {};
      };
    lockInfos = l.flatten (
      l.map
      (
        name:
          l.map
          (version: {inherit name version;})
          (l.attrNames locksTree.directories.${name}.directories)
      )
      (l.attrNames locksTree.directories)
    );

    getDreamLock = {
      name,
      version,
    }: let
      lock = l.tryEval (
        (
          locksTree.getNodeFromPath
          "${name}/${version}/dream-lock.json"
        )
        .jsonContent
      );
    in
      if lock.success
      then lock.value
      else {};

    mkPkg = dreamLock:
      l.head (
        l.attrValues
        (d2n.makeOutputsForDreamLock {
          inherit dreamLock;
        })
        .packages
      );

    pkgsUnfiltered =
      l.map
      (
        info: let
          dreamLock = getDreamLock info;
        in
          if l.length (l.attrNames dreamLock) == 0
          then null
          else
            l.nameValuePair
            (ilib.sanitizeOutputName "${info.name}-${info.version}")
            (mkPkg dreamLock)
      )
      lockInfos;
    pkgsFiltered = l.filter (pkg: pkg != null) pkgsUnfiltered;
  in
    l.listToAttrs pkgsFiltered
