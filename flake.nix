{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs = inputs: {
    lib = import ./lib {inherit inputs;};
    templates.default = {
      description = "template for indexes.";
      path = ./template;
    };
  };
}
