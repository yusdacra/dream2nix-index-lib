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

    mkLib = {
      system,
      indexName,
    }: let
      pkgs = nixpkgs.legacyPackages.${system};

      callPackage = f: args:
        pkgs.callPackage f (args // {inherit dream2nix system indexName;});

      fetcher = callPackage ./fetch.nix {};
      translator = callPackage ./translate.nix {};
    in
      fetcher
      // translator
      // {
        inherit callPackage;
        # pkg: {name, version, hash}
        dreamLockFor = pkg: let
          srcInfo = fetcher.fetch pkg;
          pkgWithSrc = pkg // srcInfo;
          dreamLock = translator.translate pkgWithSrc;
        in
          dreamLock;
        flattenIndex = callPackage ./flattenIndex.nix {};
      };
  in {
    lib = {inherit mkLib;};
  };
}
