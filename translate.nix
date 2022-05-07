{
  dream2nix,
  system,
  lib,
  subsystem,
  fetcherName,
  translatorForPath,
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
    # imported source tree
    tree ? dlib.prepareSourceTree {inherit (sourceInfo) source;},
  }: let
    # determine translator
    translatorNames = l.attrValues (
      l.filterAttrs
      (path: _: (l.tryEval (tree.getNodeFromPath path)).success)
      translatorForPath
    );
    translatorName =
      if l.length translatorNames == 0
      then
        translatorForFile."__default"
        or (throw "could not determine translator for '${name}-${version}' (source '${tree.fullPath}')")
      else l.head translatorNames;

    # craft the project
    project = dlib.construct.discoveredProject {
      inherit subsystem name;
      translators = [translatorName];
      relPath = "";
      subsystemInfo = {};
    };

    # get the translator
    translator = d2n.translators.translators.${project.subsystem}.all.${translatorName};

    # translate the project
    dreamLock' = translator.translate {
      inherit tree project;
      inherit (sourceInfo) source;
      discoveredProjects = [project];
    };
    # simpleTranslate2 uses .result
    dreamLock = dreamLock'.result or dreamLock';
    # patch this package's dependency to not use path source.
    dreamLockPatched =
      l.updateManyAttrsByPath [
        {
          path = ["sources" name version];
          update = _: {type = fetcherName;} // (l.removeAttrs sourceInfo ["source"]);
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
