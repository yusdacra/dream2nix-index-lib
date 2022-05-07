{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    dream2nix,
    nixpkgs,
    ...
  }: let
    l = nixpkgs.lib // builtins;

    systems = ["x86_64-linux"];

    # system: the (host) system to use (example: "x86_64-linux")
    # subsystem: the dream2nix subsystem name (example: "rust")
    # translatorName: the name of the dream2nix translator to use (example: "cargo-lock")
    # fetcherName: the name of the dream2nix fetcher to use (example: "crates-io")
    mkLib = {system, ...} @ attrs: let
      pkgs = nixpkgs.legacyPackages.${system};

      callPackage = f: args:
        pkgs.callPackage f (args // attrs // {inherit dream2nix;});

      fetcher = callPackage ./fetch.nix {};
      translator = callPackage ./translate.nix {};
      flattenIndex = callPackage ./flattenIndex.nix {};
      translateBin = callPackage ./translateBin.nix {};
      mkLocksOutputs = callPackage ./mkLocksOutputs.nix {};

      # pkg: {name, version, ?hash, ...}
      # extra attrs aren't removed
      dreamLockFor = pkg: let
        sourceInfo = fetcher.fetch pkg;
        pkgWithSrc =
          (l.getAttrs ["name" "version"] pkg) // {inherit sourceInfo;};
        dreamLock = translator.translate pkgWithSrc;
      in
        dreamLock;
    in
      fetcher
      // translator
      // {
        inherit
          callPackage
          flattenIndex
          translateBin
          mkLocksOutputs
          dreamLockFor
          ;
      };
  in {
    lib = {inherit mkLib;};
  };
}
