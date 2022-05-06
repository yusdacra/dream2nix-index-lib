{
  dream2nix,
  lib,
  system,
  fetcherName,
  ...
}: let
  l = lib // builtins;

  fetchOutputs = dream2nix.lib.${system}.fetchers.fetchers.${fetcherName}.outputs;

  # fetch one package.
  fetch = {
    # name of the package.
    name,
    # version of the package.
    version,
    ...
  } @ attrs: let
    outputs = fetchOutputs {
      pname = name;
      inherit version;
    };
    hash = attrs.hash or (outputs.calcHash "sha256");
    source = outputs.fetched hash;
  in
    (l.removeAttrs ["name" "version" attrs]) // {inherit source hash;};

  # fetches an index.
  fetchIndex = index:
    l.mapAttrs
    (
      name: versions:
        l.mapAttrs
        (
          version: hash:
            fetch {
              inherit
                name
                version
                hash
                ;
            }
        )
        versions
    )
    index;
in {inherit fetchIndex fetch;}
