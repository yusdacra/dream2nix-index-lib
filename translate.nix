{
  dream2nix,
  system,
  lib,
  indexName,
  ...
}: let
  l = lib // builtins;

  d2n = dream2nix.lib.${system};
  dlib = dream2nix.lib.dlib;

  # translates one package and outputs it's dream-lock.
  translate = {
    # name of the package
    name,
    # version of the package
    version,
    # this must contain `source` at least
    sourceInfo,
  }: let
    tree = dlib.prepareSourceTree {inherit (sourceInfo) source;};
    discoveredProjects = dlib.discoverProjects {inherit tree;};
    dreamLock' = translator.translate {
      inherit tree discoveredProjects;
      # get the first project, there should only be one anyways
      project = l.elemAt discoveredProjects 0;
    };
    # simpleTranslate2 uses .result
    dreamLock = dreamLock'.result or dreamLock';
    # patch this package's dependency to use crates-io source
    # and not a path source.
    dreamLockPatched =
      l.updateManyAttrsByPath [
        {
          path = ["sources" name version];
          update = _: {type = indexName;} // (l.removeAttrs ["source"] sourceInfo);
        }
      ]
      dreamLock;
    # compress the dream lock
    dreamLockCompressed = d2n.utils.dreamLock.compressDreamLock dreamLockPatched;
  in
    dreamLockCompressed;

  # translates packages in a fetchedIndex.
  translateIndex = fetchedIndex:
    l.mapAttrs
    (
      name: versions:
        l.mapAttrs
        (
          version: sourceInfo:
            translate {inherit name version sourceInfo;}
        )
        versions
    )
    fetchedIndex;
in {inherit translate translateIndex;}
