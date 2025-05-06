{
  maintainer ? builtins.abort "maintainer argument is required",
  nixpkgsPath ? builtins.abort "nixpkgsPath argument is required",
  extraPackageSets ? "",
}:
let
  pkgs = import nixpkgsPath { };
  lib = pkgs.lib;
  maintainerHandle = maintainer;
  maxDepth = 3;
  packageSets = if extraPackageSets == "" then [ ] else lib.strings.splitString "," extraPackageSets;
  shouldRecurse = name: lib.any (setName: setName == name) packageSets;
  targetMaintainer =
    lib.maintainers.${maintainerHandle}
      or (throw "Maintainer handle '${maintainerHandle}' not found in nixpkgs/maintainers/maintainer-list.nix");
  findRec =
    currentDepth: pathPrefix: currentAttrSet:
    lib.flatten (
      lib.mapAttrsToList (
        name: value:
        let
          evalResult = builtins.tryEval (
            let
              currentPath = pathPrefix ++ [ name ];
              fullPathString = lib.concatStringsSep "." currentPath;
            in
            let
              isMatch = (
                (lib.isDerivation value)
                && (value ? meta)
                && (value.meta ? maintainers)
                && (lib.isList value.meta.maintainers)
                && (lib.any (m: m == targetMaintainer) value.meta.maintainers)
              );
            in
            if isMatch then
              [ fullPathString ]
            else if currentDepth < maxDepth && lib.isAttrs value && shouldRecurse name then
              findRec (currentDepth + 1) currentPath value
            else
              [ ]
          );
        in
        if evalResult.success then evalResult.value else [ ]
      ) currentAttrSet
    );
  allMatchingPaths = findRec 0 [ "pkgs" ] pkgs;
  processedPaths = map (path: lib.strings.removePrefix "pkgs." path) allMatchingPaths;
in
lib.sort lib.lessThan processedPaths
