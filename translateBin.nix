{
  lib,
  writeScript,
  moreutils,
  stdenv,
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
      mkdir -p ${dirPath}
      nix eval --impure --json --file ${expr} > ${dirPath}/dream-lock.json
    '';
  in
    l.toFile "translate-${pkg.name}-${pkg.version}.sh" command;
in
  # pkgs: [{name, version, ?hash, ...}]
  pkgs: let
    invocations = l.map mkTranslateCommand pkgs;
    commands = l.map (invocation: "\"${stdenv.shell} ${invocation}\"") invocations;
    script = ''${moreutils}/bin/parallel -- ${l.concatStringsSep " " commands}'';
  in
    writeScript "translate.sh" script
