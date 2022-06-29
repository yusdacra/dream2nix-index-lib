{
  inputs = {
    dream2nix.url = "github:nix-community/dream2nix";
  };

  outputs = inputs: {
    lib = import ./lib {inherit inputs;};
  };
}
