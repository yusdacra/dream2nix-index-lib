{
  lib,
  pkgs-dlib,
  # ilib config
  fetcherName,
  ...
}: let
  l = lib;

  # fetch one package.
  fetch = {
    # name of the package.
    name,
    # version of the package.
    version,
    ...
  } @ attrs: let
    fetchOutputs = pkgs-dlib.fetchers.fetchers.${fetcherName}.outputs;

    outputs = fetchOutputs {
      pname = name;
      inherit version;
    };
    hash = attrs.hash or (outputs.calcHash "sha256");
    source = outputs.fetched hash;
  in
    (l.removeAttrs attrs ["name" "version"]) // {inherit source hash;};

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
