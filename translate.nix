{
  dream2nix,
  system,
  lib,
  subsystem,
  translatorName,
  fetcherName,
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
    # craft the project
    project = dlib.construct.discoveredProject {
      inherit subsystem name;
      translator = translatorName;
      translators = [translatorName];
      relPath = "";
      subsystemInfo = {};
    };

    # get the translator
    translatorName = project.translator or (l.head project.translators);
    translator = d2n.translators.translators.${project.subsystem}.all.${translatorName};

    # translate the project
    dreamLock' = translator.translate {
      inherit tree discoveredProjects project;
    };
    # simpleTranslate2 uses .result
    dreamLock = dreamLock'.result or dreamLock';
    # patch this package's dependency to not use path source.
    dreamLockPatched =
      l.updateManyAttrsByPath [
        {
          path = ["sources" name version];
          update = _: {type = fetcherName;} // (l.removeAttrs ["source"] sourceInfo);
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
      name: versions: let
        # extend the versions with the dream-lock
        computedVersions =
          l.mapAttrs
          (
            version: sourceInfo: let
              tree = dlib.prepareSourceTree {inherit (sourceInfo) source;};
            in {
              inherit tree;
              lock = translate {inherit name version sourceInfo tree;};
            }
          )
          versions;
        # filter out versions that don't have Cargo.lock file
        # since they can't be translated
        versionsWithLock =
          l.filterAttrs
          (_: attrs: attrs.tree.files ? "Cargo.lock")
          computedVersions;
        # remove the source tree
        usableVersions = l.mapAttrs (_: attrs: attrs.lock) versionsWithLock;
      in
        usableVersions
    )
    fetchedIndex;
in {inherit translate translateIndex;}
