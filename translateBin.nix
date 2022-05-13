{
  lib,
  writeScript,
  moreutils,
  coreutils,
  bash,
  jq,
  # ilib
  ilib,
  ilibInputs,
  system,
  subsystem,
  fetcherName,
  translatorForPath,
  genDirectory ? "gen/",
  ...
}: let
  l = lib // builtins;
  sanitize = ilib.utils.sanitizeDerivationName;

  flakeInputsExpr = let
    inputs = l.removeAttrs ilibInputs ["self"];
    getFlakeExprs =
      l.mapAttrs
      (name: value: ilib.utils.mkGetFlakeExprForInput value)
      inputs;
    attrs = l.mapAttrsToList (n: v: ''"${n}" = ${v};'') getFlakeExprs;
  in ''
    {
      ${l.concatStringsSep "\n" attrs}
    }
  '';

  mkTranslateExpr = pkg: let
    attrs = {
      inherit
        system
        subsystem
        fetcherName
        translatorForPath
        ;
    };

    attrsFile = l.toFile "attrs.json" (l.toJSON attrs);
    pkgFile = l.toFile "args.json" (l.toJSON pkg);

    systemAttr = "$" + "{config.system}";
    subsystemAttr = "$" + "{config.subsystem}";
    translatorAttr = "$" + "{translatorName}";

    expr = ''
      let
        inputs = ${flakeInputsExpr};
        ilibFlake =
          ((import "${./.}/flake.nix").outputs inputs)
          // {inherit inputs;};

        l = ilibFlake.inputs.nixpkgs.lib // builtins;
        readJSON = path: l.fromJSON (l.readFile path);

        config = readJSON ${attrsFile};
        ilib = ilibFlake.lib.mkLib config;
        d2n = ilibFlake.inputs.dream2nix.lib;
        translators = d2n.${systemAttr}.translators.translators.${subsystemAttr};

        pkg = readJSON ${pkgFile};
        sourceInfo = ilib.fetch pkg;
        tree = d2n.dlib.prepareSourceTree {inherit (sourceInfo) source;};
        pkgWithSrc =
          (l.getAttrs ["name" "version"] pkg) // {inherit sourceInfo;};
        translatorName = ilib.determineTranslator {inherit tree;};

        lock = with ilib;
          if l.hasAttr translatorName translators.pure
          then translate (pkgWithSrc // {inherit tree;})
          else {
            script =
              translators.impure.${translatorAttr}.translateBin.drvPath
              or (throw "did not find impure translator ${translatorAttr}");
            args =
              (mkTranslatorArguments {
                inherit sourceInfo translatorName;
                inherit (pkg) name;
              })
              // {
                sourceHash = sourceInfo.hash;
                sourceType = config.fetcherName;
              };
          };
      in lock
    '';
  in
    l.toFile (sanitize "translate-${pkg.name}-${pkg.version}.nix") expr;
  mkTranslateCommand = pkg: let
    inherit (pkg) name version;

    dirPath = "${genDirectory}locks/${sanitize name}/${sanitize version}";
    expr = mkTranslateExpr pkg;
    command = ''
      # create temporary lock path, attempt to translate
      lock="$(mktemp)"
      nix eval --json --file "${expr}" > "$lock" || exit 1

      # try to get translator script. if it exists it means
      # the translation is impure. if not it was successful.
      outlock="${dirPath}/dream-lock.json"
      scriptDrv="$($jqexe .script -c -r $lock)"
      if [[ "$scriptDrv" == "null" ]]; then
        # make lock directory path, write the lock
        mkdir -p "${dirPath}"
        $jqexe . -r "$lock" > "$outlock"
      else
        # actually build our script
        scriptBuild="$(mktemp)"
        nix build --no-link --json "$scriptDrv" > "$scriptBuild" || exit 2

        # get script path, create translator args file
        script="$($jqexe '.[0].outputs.out' -c -r $scriptBuild)"
        args="$(mktemp)"
        $jqexe ".args.outputFile = \"$outlock\" | .args" -c -r "$lock" > "$args"

        # run translator script
        "$script" "$args" || exit 3

        # make lock directory path, write the lock
        # also patch up the source for our package
        mkdir -p "${dirPath}"
        pkgSrc="{\
          \"hash\":\"$($jqexe .sourceHash -c -r $args)\",\
          \"type\":\"$($jqexe .sourceType -c -r $args)\"\
        }"
        $jqexe ".sources.\"${name}\".\"${version}\" = $pkgSrc" -r "$outlock" \
          | $spgexe "$outlock"
      fi
    '';
  in
    l.toFile (sanitize "translate-${name}-${version}.sh") command;

  mkTranslateScript = {pkgs}: let
    env = ''spgexe="${moreutils}/bin/sponge" "jqexe=${jq}/bin/jq"'';
    invocations = l.map mkTranslateCommand pkgs;
    commands =
      l.map
      (invocation: "\"$timeoutexe 600s $shexe -c '${env} . ${invocation}'\"")
      invocations;
    script = let
      jobs = "$" + "{" + "JOBS:+\"-j $JOBS\"" + "}";
    in
      if l.length commands == 0
      then ''echo "no (new) packages to translate."''
      else ''
        timeoutexe="${coreutils}/bin/timeout"
        shexe="${bash}/bin/bash"
        mkdir -p ${genDirectory}locks
        ${moreutils}/bin/parallel ${jobs} -- ${l.concatStringsSep " " commands}
      '';
  in
    writeScript "translate.sh" script;

  mkTranslateIndexScript = {genTree}: let
    index = genTree.files."index.json".jsonContent or {};
    _pkgs =
      l.mapAttrsToList
      (
        name: versions:
          l.mapAttrsToList
          (version: hash: {inherit name version hash;})
          versions
      )
      index;
    pkgs = l.flatten _pkgs;
    locksTree = genTree.directories."locks" or null;

    # filter out packages that have already been translated
    filteredPkgs =
      l.filter
      (
        pkg:
          (
            locksTree
            .directories
            ."${sanitize pkg.name}"
            .directories
            ."${sanitize pkg.version}"
            .files
            ."dream-lock.json"
            or null
          )
          == null
      )
      pkgs;
  in
    mkTranslateScript {pkgs = filteredPkgs;};
in {inherit mkTranslateScript mkTranslateIndexScript;}
