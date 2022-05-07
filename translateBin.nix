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
  translatorName,
  genDirectory ? "gen/",
  ...
}: let
  l = lib // builtins;

  mkTranslateExpr = pkg: let
    attrs = {
      inherit
        system
        subsystem
        fetcherName
        translatorName
        ;
    };
    attrsFile = l.toFile "attrs.json" (l.toJSON attrs);
    pkgFile = l.toFile "args.json" (l.toJSON pkg);
  in ''
    let
      b = builtins;
      readJSON = path: b.fromJSON (b.readFile path);
    in
    (
      (builtins.getFlake (toString ${./.})).lib.mkLib
      (readJSON ${attrsFile})
    ).dreamLockFor (readJSON ${pkgFile})
  '';
  mkTranslateCommand = pkg: let
    expr =
      l.toFile
      "translate-${pkg.name}-${pkg.version}.nix"
      (mkTranslateExpr pkg);
    dirPath = "${genDirectory}locks/${pkg.name}/${pkg.version}";
    command = ''
      lock="$(nix eval --impure --json --file ${expr})"
      if [ $? -eq 0 ]; then
        mkdir -p ${dirPath}
        echo "$lock" | $jqexe . > ${dirPath}/dream-lock.json
      fi
    '';
  in
    l.toFile "translate-${pkg.name}-${pkg.version}.sh" command;
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
