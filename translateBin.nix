{
  lib,
  writeScript,
  moreutils,
  stdenv,
  jq,
  # ilib
  system,
  subsystem,
  fetcherName,
  translatorForPath,
  genDirectory ? "gen/",
  ...
}: let
  l = lib // builtins;

  mkTranslateExpr = {
    pkg,
    dirPath,
  }: let
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
  in ''
    let
      ilibFlake = builtins.getFlake (toString ${./.});

      l = ilibFlake.inputs.nixpkgs.lib // builtins;
      readJSON = path: l.fromJSON (l.readFile path);

      config = readJSON ${attrsFile};
      ilib = ilibFlake.lib.mkLib config;
      pkgs = ilibFlake.inputs.nixpkgs.legacyPackages.${systemAttr};
      d2n = ilibFlake.inputs.dream2nix.lib;
      translators = d2n.${systemAttr}.translators.translators.${subsystemAttr};

      pkg = readJSON ${pkgFile};
      sourceInfo = ilib.fetch pkg;
      tree = d2n.dlib.prepareSourceTree {inherit (sourceInfo) source;};
      pkgWithSrc =
        (l.getAttrs ["name" "version"] pkg) // {inherit sourceInfo;};
      translatorName = ilib.determineTranslator {inherit tree;};

      lock = with ilib;
        if translators.pure ? translatorName
        then translate (pkgWithSrc // {inherit tree;})
        else {
          script = translators.impure.${translatorAttr}.translateBin;
          args =
            pkgs.writeText
            "translator-args.json"
            (
              l.toJSON
              (
                (mkTranslatorArguments {
                  inherit sourceInfo translatorName;
                  inherit (pkg) name;
                })
                // {
                  outputFile = "${dirPath}/dream-lock.json";
                  sourceHash = sourceInfo.hash;
                  sourceType = config.fetcherName;
                }
              )
            );
        };
    in pkgs.writeText "lock.json" (l.toJSON lock)
  '';
  mkTranslateCommand = pkg: let
    inherit (pkg) name version;
    sanitize = l.strings.sanitizeDerivationName;

    dirPath = "${genDirectory}locks/${sanitize name}/${sanitize version}";
    expr =
      l.toFile
      (sanitize "translate-${name}-${version}.nix")
      (mkTranslateExpr {inherit pkg dirPath;});
    command = ''
      build="$(nix build --no-link --impure --json --file ${expr})"
      lock="$(echo $build | $jqexe '.[0].outputs.out' -c -r)"
      if [ $? -eq 0 ]; then
        mkdir -p "${dirPath}"
        outlock="${dirPath}/dream-lock.json"
        script="$($jqexe .script -c -r $lock)"
        if [[ "$script" == "null" ]]; then
          $jqexe . -r $lock > $outlock
        else
          args="$($jqexe .args -c -r $lock)"
          $script $args
          pkgSrc="{\
            \"hash\":\"$($jqexe .sourceHash -c -r $args)\",\
            \"type\":\"$($jqexe .sourceType -c -r $args)\"\
          }"
          $jqexe ".sources.\"${name}\".\"${version}\" = $pkgSrc" -r $outlock \
            | $spgexe $outlock
        fi
      fi
    '';
  in
    l.toFile
    (sanitize "translate-${name}-${version}.sh")
    command;
in
  # pkgs: [{name, version, ?hash, ...}]
  pkgs: let
    env = "spgexe=${moreutils}/bin/sponge jqexe=${jq}/bin/jq";
    invocations = l.map mkTranslateCommand pkgs;
    commands =
      l.map
      (invocation: "\"$shexe -c '${env} . ${invocation}'\"")
      invocations;
    script = let
      jobs = "$" + "{" + "JOBS:+\"-j $JOBS\"" + "}";
    in ''
      shexe=${stdenv.shell}
      ${moreutils}/bin/parallel ${jobs} -- ${l.concatStringsSep " " commands}
    '';
  in
    writeScript "translate.sh" script
