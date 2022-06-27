{
  lib,
  utils,
  ...
}: let
  l = lib;
in
  # indexTree: an index tree prepared with `utils.prepareIndexTree`.
  # this should be the source tree of a generated index directory.
  {
    indexTree,
    makeOutputsForDreamLock,
  }: let
    locksTree =
      indexTree.directories."locks"
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
      lockFile =
        locksTree.getNodeFromPath
        "${name}/${version}/dream-lock.json";
    in
      if l.stringLength lockFile.content > 0
      then lockFile.jsonContent
      else null;

    mkPkg = dreamLock:
      l.head (
        l.attrValues
        (makeOutputsForDreamLock {
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
          if dreamLock == null
          then null
          else
            l.nameValuePair
            (utils.sanitizeOutputName "${info.name}-${info.version}")
            (mkPkg dreamLock)
      )
      lockInfos;
    pkgsFiltered = l.filter (pkg: pkg != null) pkgsUnfiltered;
  in
    l.listToAttrs pkgsFiltered
