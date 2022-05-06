{lib, ...}: let
  l = lib // builtins;
in
  index:
    l.listToAttrs (l.flatten (l.attrValues (
      l.mapAttrs
      (
        name: versions:
          l.attrValues (
            l.mapAttrs
            (
              version: value: {
                name = "${name}-${version}";
                inherit value;
              }
            )
            versions
          )
      )
      index
    )))
