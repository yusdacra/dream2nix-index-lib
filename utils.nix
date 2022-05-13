{
  lib,
  dream2nix,
  ...
}: let
  fromStrings = ["@" "/"];
  toStrings = ["__at__" "__slash__"];

  sanitizeDerivationName = name:
    lib.replaceStrings fromStrings toStrings name;

  fromOutStrings = fromStrings ++ ["+" "."];
  toOutStrings = toStrings ++ ["_" "_"];

  sanitizeOutputName = name:
    lib.replaceStrings fromOutStrings toOutStrings name;

  escapePath = path: lib.escape ["/"] path;

  mkGetFlakeExprForInput = input: ''builtins.getFlake "path:${toString input}?narHash=${input.narHash}"'';

  prepareIndexTree = {path}:
    dream2nix.lib.dlib.prepareSourceTree {source = path;};
in {
  inherit
    sanitizeDerivationName
    sanitizeOutputName
    escapePath
    mkGetFlakeExprForInput
    prepareIndexTree
    ;
}
