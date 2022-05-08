{lib, ...}: let
  fromStrings = ["@" "/"];
  toStrings = ["__at__" "__slash__"];

  sanitizeDerivationName = name:
    lib.replaceStrings fromStrings toStrings name;

  fromOutStrings = fromStrings ++ ["+" "."];
  toOutStrings = toStrings ++ ["__plus__" "__dot__"];

  sanitizeOutputName = name:
    lib.replaceStrings fromOutStrings toOutStrings name;

  escapePath = path: lib.escape ["/"] path;
in {
  inherit
    sanitizeDerivationName
    sanitizeOutputName
    escapePath
    ;
}
