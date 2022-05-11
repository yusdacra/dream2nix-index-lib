{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = {
    dream2nix,
    nixpkgs,
    ...
  } @ inputs: let
    l = nixpkgs.lib // builtins;

    systems = ["x86_64-linux"];

    # system: the (host) system to use (example: "x86_64-linux")
    # subsystem: the dream2nix subsystem name (example: "rust")
    # fetcherName: the name of the dream2nix fetcher to use (example: "crates-io")
    # translatorForPath: if path exists, translator will be marked as valid
    mkLib = {system, ...} @ attrs: let
      pkgs = nixpkgs.legacyPackages.${system};

      callPackage = f: args:
        pkgs.callPackage f (args
          // attrs
          // {
            inherit dream2nix ilib;
            ilibInputs = inputs;
          });

      fetcher = callPackage ./fetch.nix {};
      translator = callPackage ./translate.nix {};
      translateBin = callPackage ./translateBin.nix {};
      mkLocksOutputs = callPackage ./mkLocksOutputs.nix {};
      utils = callPackage ./utils.nix {};

      # pkg: {name, version, ?hash, ...}
      # extra attrs aren't removed
      dreamLockFor = pkg: let
        sourceInfo = fetcher.fetch pkg;
        pkgWithSrc =
          (l.getAttrs ["name" "version"] pkg) // {inherit sourceInfo;};
        dreamLock = translator.translate pkgWithSrc;
      in
        dreamLock;

      ilib =
        fetcher
        // translator
        // {
          inherit
            translateBin
            mkLocksOutputs
            dreamLockFor
            utils
            ;
        };
    in
      ilib;
  in {
    lib = {inherit mkLib;};
  };
}
