{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    lib = import ./lib {inherit inputs;};
    templates.default = {
      description = "template for indexes.";
      path = ./template;
    };
  };
}
