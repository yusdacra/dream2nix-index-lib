{inputs}: let
  callLib = _f: args: let
    f =
      if builtins.isPath _f
      then import _f
      else if builtins.isFunction _f
      then _f
      else throw "value must be a function or a path pointing to a Nix file containing a function";

    argsToAdd = rec {
      dlib = import "${inputs.dream2nix}/src/lib" {inherit lib;};
      lib = inputs.nixpkgs-lib.lib // builtins;
    };
  in
    f (argsToAdd // args);
in rec {
  utils = callLib ./utils.nix {};
  mkLocksOutputs = callLib ./mkLocksOutputs.nix {inherit utils;};
}
