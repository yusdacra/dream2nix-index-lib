{
  lib,
  writeScript,
  parallel,
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
  in ''
    (
      (builtins.getFlake (toString ${./.})).lib.mkLib
      (builtins.fromJSON "${l.toJSON attrs}")
    ).dreamLockFor (builtins.fromJSON "${l.toJSON pkg}")
  '';
  mkTranslateCommand = pkg: let
    expr =
      l.toFile
      "translate-${pkg.name}-${pkg.version}"
      (mkTranslateExpr pkg);
    dirPath = "${genDirectory}locks/${pkg.name}/${pkg.version}";
  in ''
    mkdir -p ${dirPath}
    nix eval --impure --json --file ${expr} > ${dirPath}/dream-lock.json
  '';
in
  # pkgs: [{name, version, ?hash, ...}]
  pkgs: let
    commandsRaw = l.map mkTranslateCommand pkgs;
    commandsQuoted = l.map (cmd: "\"${cmd}\"") commands;
    commands = l.concatStringsSep " " commandsQuoted;
    script = ''${parallel}/bin/parallel -- ${commands}'';
  in
    writeScript "translate.sh" script
