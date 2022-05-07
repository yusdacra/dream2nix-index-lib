{
  dream2nix,
  lib,
  system,
  ...
}: let
  l = lib // builtins;

  d2n = dream2nix.lib.${system};
in
  # tree: a source tree prepared with `dream2nix`'s `prepareSourceTree`.
  # this should be the source tree of a generated index directory.
  {tree}: let
    locksTree = tree.directories."locks";
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

    sanitizePkgName = name: l.replaceStrings ["." "+"] ["_" "_"] name;
    mkPkg = name: version:
      (d2n.makeOutputsForDreamLock {
        dreamLock =
          (
            locksTree.getNodeFromPath
            "${name}/${version}/dream-lock.json"
          )
          .jsonContent;
      })
      .packages
      .${name};

    pkgs =
      l.map
      (
        info:
          l.nameValuePair
          (sanitizePkgName "${info.name}-${info.version}")
          (mkPkg info.name info.version)
      )
      lockInfos;
  in
    l.listToAttrs pkgs