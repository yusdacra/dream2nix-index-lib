{lib, ...}: let
  fromStrings = ["@" "/"];
  toStrings = ["__at__" "__slash__"];

  sanitizeDerivationName = name:
    lib.replaceStrings fromStrings toStrings name;
  desanitizeDerivationName = name:
    lib.replaceStrings toStrings fromStrings name;

  fromOutStrings = fromStrings ++ ["+" "."];
  toOutStrings = toStrings ++ ["__plus__" "__dot__"];

  sanitizeOutputName = name:
    lib.replaceStrings fromOutStrings toOutStrings name;
  desanitizeOutputName = name:
    lib.replaceStrings toOutStrings fromOutStrings name;
in {
  inherit
    sanitizeDerivationName
    desanitizeDerivationName
    sanitizeOutputName
    desanitizeOutputName
    ;
}
