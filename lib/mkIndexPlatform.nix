{
  lib,
  inputs,
  ...
} @ libAttrs: let
  l = lib;
in
  # system: the (host) system to use (example: "x86_64-linux")
  # subsystem: the dream2nix subsystem name (example: "rust")
  # fetcherName: the name of the dream2nix fetcher to use (example: "crates-io")
  # translatorForPath: if path exists, translator will be marked as valid
  {system, ...} @ attrs: let
    pkgs = inputs.nixpkgs.legacyPackages.${system};

    callPackage = f: args:
      pkgs.callPackage f
      (
        libAttrs
        // attrs
        // {
          inherit utils;
          pkgs-dlib = inputs.dream2nix.lib.${system};
        }
      );
    callPkg = f: callPackage f {};

    utils = callPkg ./utils.nix;
    fetch = callPkg ./fetch.nix;
    translate = callPkg ./translate.nix;
    translateScript = callPkg ./translateScript.nix;
    mkLocksOutputs = callPkg ./mkLocksOutputs.nix;

    # pkg: {name, version, ?hash, ...}
    # extra attrs aren't removed
    dreamLockFor = pkg: let
      sourceInfo = fetch.fetch pkg;
      pkgWithSrc =
        (l.getAttrs ["name" "version"] pkg) // {inherit sourceInfo;};
      dreamLock = translate.translate pkgWithSrc;
    in
      dreamLock;
  in
    fetch
    // translate
    // translateScript
    // {
      inherit
        mkLocksOutputs
        dreamLockFor
        utils
        ;
    }
