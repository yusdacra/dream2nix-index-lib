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
            l.toFile
            "translator-args.json"
            (
              l.toJSON
              ((makeTranslatorArguments {
                inherit sourceInfo translatorName;
                inherit (pkg) name;
              }) // {outputFile = "${dirPath}/dream-lock.json";})
            );
        };
    in l.toFile "lock.json" (l.toJSON lock)
  '';
  mkTranslateCommand = pkg: let
    inherit (pkg) name version;

    dirPath = "${genDirectory}locks/${name}/${version}";
    expr =
      l.toFile
      "translate-${name}-${version}.nix"
      (mkTranslateExpr {inherit pkg dirPath;});
    command = ''
      lock="$(nix eval --impure --raw --file ${expr})"
      if [ $? -eq 0 ]; then
        mkdir -p ${dirPath}
        script="$($jqexe .script -c -r $lock)"
        if [[ "$script" == "null" ]]; then
          cat $lock | $jqexe . > ${dirPath}/dream-lock.json
        else
          args="$($jqexe .args -c -r $lock)"
          $script $args
        fi
      fi
    '';
  in
    l.toFile "translate-${name}-${version}.sh" command;
in
  # pkgs: [{name, version, ?hash, ...}]
  pkgs: let
    invocations = l.map mkTranslateCommand pkgs;
    commands =
      l.map
      (invocation: "\"$shexe -c 'jqexe=${jq}/bin/jq . ${invocation}'\"")
      invocations;
    script = let
      jobs = "$" + "{" + "JOBS:+\"-j $JOBS\"" + "}";
    in ''
      shexe=${stdenv.shell}
      ${moreutils}/bin/parallel ${jobs} -- ${l.concatStringsSep " " commands}
    '';
  in
    writeScript "translate.sh" script
