{
  inputs = {
    nixpkgs-lib.url = "github:nix-community/nixpkgs.lib";
    dream2nix.url = "github:nix-community/dream2nix";
    dream2nix.flake = false;
  };

  outputs = inputs: {
    lib = import ./lib {inherit inputs;};
  };
}
