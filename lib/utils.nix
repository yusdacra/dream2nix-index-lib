{
  lib,
  dlib,
  ...
}: let
  l = lib;

  fromStrings = ["@" "/"];
  toStrings = ["__at__" "__slash__"];

  sanitizeDerivationName = name:
    l.replaceStrings fromStrings toStrings name;

  fromOutStrings = fromStrings ++ ["+" "."];
  toOutStrings = toStrings ++ ["_" "_"];

  sanitizeOutputName = name:
    l.replaceStrings fromOutStrings toOutStrings name;

  escapePath = path: l.escape ["/"] path;

  mkGetFlakeExprForInput = input: ''builtins.getFlake "path:${toString input}?narHash=${input.narHash}"'';

  prepareIndexTree = {path}:
    dlib.prepareSourceTree {source = path;};
in {
  inherit
    sanitizeDerivationName
    sanitizeOutputName
    escapePath
    mkGetFlakeExprForInput
    prepareIndexTree
    ;
}
