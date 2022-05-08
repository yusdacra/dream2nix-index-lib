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

    mkPkg = name: version:
      l.head (
        l.attrValues
        (d2n.makeOutputsForDreamLock {
          dreamLock =
            (
              locksTree.getNodeFromPath
              "${name}/${version}/dream-lock.json"
            )
            .jsonContent;
        })
        .packages
      );

    pkgs =
      l.map
      (
        info:
          l.nameValuePair
          (ilib.sanitizeOutputName "${info.name}-${info.version}")
          (mkPkg info.name info.version)
      )
      lockInfos;
  in
    l.listToAttrs pkgs
