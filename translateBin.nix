{
  lib,
  writeScript,
  system,
  subsystem,
  fetcherName,
  translatorName,
  parallel,
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
  in ''nix eval --impure --json --file ${expr}'';
in
  # pkgs: [{name, version, ?hash, ...}]
  pkgs: let
    commandsRaw = l.map mkTranslateCommand pkgs;
    commandsQuoted = l.map (cmd: "\"${cmd}\"") commands;
    commands = l.concatStringsSep " " commandsQuoted;
    script = ''${parallel}/bin/parallel -- ${commands}'';
  in
    writeScript "translate.sh" script
