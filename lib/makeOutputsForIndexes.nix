{
  inputs,
  lib,
  ...
}: {
  source,
  indexesForSystems,
  extendOutputs ? args: prevOutputs: {},
}: let
  l = lib // builtins;
  mkApp = script: {
    type = "app";
    program = toString script;
  };

  mkOutputs = system: indexNames: let
    pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages.${system};
    d2n = inputs.dream2nix.lib.init {
      inherit pkgs;
      config.projectRoot = source;
    };

    mkIndexApp = {
      name,
      input,
    } @ args: let
      input = {outputFile = "${name}/index.json";} // args.input;
      script = pkgs.writers.writeBash "index" ''
        set -e
        inputJson="$(${pkgs.coreutils}/bin/mktemp)"
        echo '${l.toJSON input}' > $inputJson
        ${d2n.apps.index}/bin/index ${name} $inputJson
      '';
    in
      mkApp script;
    mkTranslateApp = name:
      mkApp (
        pkgs.writers.writeBash "translate" ''
          set -e
          ${d2n.apps.translate-index}/bin/translate-index \
            ${name}/index.json ${name}/locks
        ''
      );
    translateApps = l.listToAttrs (
      l.map
      (
        name:
          l.nameValuePair
          "translate-${name}"
          (mkTranslateApp name)
      )
      indexNames
    );

    mkIndexOutputs = name:
      if l.pathExists "${source}/${name}/locks"
      then
        d2n.utils.generatePackagesFromLocksTree {
          source = l.path {
            name = "${name}";
            path = "${source}/${name}/locks";
          };
        }
      else {};

    allPackages =
      l.foldl'
      (acc: el: acc // el)
      {}
      (l.map mkIndexOutputs indexNames);

    outputs = {
      hydraJobs = l.mapAttrs (_: pkg: {${system} = pkg;}) allPackages;
      packages.${system} = allPackages;
      apps.${system} = translateApps;
    };
  in
    outputs
    // (
      extendOutputs
      (pkgs // {inherit pkgs d2n mkIndexApp;})
      outputs
    );
in
  l.foldl'
  (acc: el: l.recursiveUpdate acc el)
  {}
  (
    l.map
    ({
      system,
      indexNames,
    }:
      mkOutputs system indexNames)
    (
      l.mapAttrsToList
      (n: v: {
        system = n;
        indexNames = v;
      })
      indexesForSystems
    )
  )
