{
  lib,
  dlib,
  pkgs-dlib,
  # ilib config
  subsystem,
  fetcherName,
  translatorForPath,
  ...
}: let
  l = lib;

  determineTranslator = {tree}: let
    # determine translator
    translatorNames = l.attrValues (
      l.filterAttrs
      # TODO: replace this with an actual 'containsPath' function
      (path: _: (l.tryEval (tree.getNodeFromPath path)).success)
      translatorForPath
    );
    translatorName =
      if l.length translatorNames == 0
      then
        translatorForPath.__default
        or (throw "could not determine translator for source '${tree.fullPath}'")
      else l.head translatorNames;
  in
    translatorName;

  mkTranslatorArguments = {
    name,
    sourceInfo,
    translatorName,
    tree ? null,
  }: let
    # craft the project
    project = dlib.construct.discoveredProject {
      inherit subsystem name;
      translators = [translatorName];
      relPath = "";
      subsystemInfo = {};
    };
  in
    {
      inherit project;
      inherit (sourceInfo) source;
      discoveredProjects = [project];
    }
    // l.optionalAttrs (tree != null) {inherit tree;};

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
    translatorName = determineTranslator {inherit tree;};

    # get the translator
    translator = pkgs-dlib.translators.translators.${subsystem}.all.${translatorName};

    # translate the project
    dreamLock' = translator.translate (mkTranslatorArguments {
      inherit sourceInfo name translatorName tree;
    });
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
    dreamLockCompressed = pkgs-dlib.utils.dreamLock.compressDreamLock dreamLockPatched;
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
in {
  inherit
    translate
    translateIndex
    determineTranslator
    mkTranslatorArguments
    ;
}
