{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ilib = {
      url = "github:yusdacra/dream2nix-index-lib";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.dream2nix.follows = "dream2nix";
    };
  };

  outputs = inputs: let
    l = inputs.nixpkgs.lib // builtins;

    mkOutputsForSystem = system: let
      # create our ilib instance
      ilib = inputs.ilib.lib.mkIndexPlatform {
        inherit system;
        # the subsystem, ex. "rust", "nodejs"
        subsystem = "subsystem";
        # fetcher name, ex. "crates-io", "npm"
        fetcherName = "fetcher name";
        # translator to use if path exists.
        # can be used to use specific translators for specific lockfiles.
        #
        # example (for nodejs):
        # ```nix
        # {
        #   "yarn.lock" = "yarn-lock";
        #   "package-lock.json" = "package-lock";
        #   __default = "package-json";
        # }
        # ```
        translatorForPath = {
          "lock-file" = "lock-file translator";
          __default = "default translator";
        };
      };

      # our indexer. preferably this should be runnable
      # without passing some arguments, since it's used
      # in the CI file without any. but you can change
      # it to take anything of course.
      indexer = throw "implement an indexer";

      # prepare the index tree
      indexTree = ilib.utils.prepareIndexTree {path = ./gen;};
      # generate a translation script for the indexed packages
      translateScript = ilib.mkTranslateIndexScript {inherit indexTree;};
      # create flake outputs for the translated packages
      lockOutputs = ilib.mkLocksOutputs {inherit indexTree;};
    in {
      # expore index / translate apps for usage
      apps.${system} = {
        translate = {
          type = "app";
          program = toString translateScript;
        };
        index = {
          type = "app";
          program = toString indexer;
        };
      };
      # expose the translated packages under packages
      packages.${system} = lockOutputs;
      # hydra jobs for all the translated packages
      hydraJobs = l.mapAttrs (_: pkg: {${system} = pkg;}) lockOutputs;
    };

    systems = ["x86_64-linux"];
  in
    l.foldl'
    l.recursiveUpdate
    {}
    (l.map mkOutputsForSystem systems);
}
