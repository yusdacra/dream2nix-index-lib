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
      pkgs.callPackage f (libAttrs
        // attrs
        // {
          inherit utils;
          pkgs-dlib = inputs.dream2nix.lib.${system};
        });

    utils = callPackage ./utils.nix {};
    fetch = callPackage ./fetch.nix {};
    translate = callPackage ./translate.nix {};
    translateScript = callPackage ./translateScript.nix {};
    mkLocksOutputs = callPackage ./mkLocksOutputs.nix {};

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
