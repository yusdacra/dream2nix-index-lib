{inputs}: let
  callLib = _f: args: let
    f =
      if builtins.isPath _f
      then import _f
      else if builtins.isFunction _f
      then _f
      else throw "value must be a function or a path pointing to a Nix file containing a function";
  in
    f (
      {
        inherit inputs;
        inherit (inputs.dream2nix.lib) dlib;
        lib = inputs.nixpkgs.lib // builtins;
      }
      // args
    );
in {
  mkIndexPlatform = callLib ./mkIndexPlatform.nix {};
}
