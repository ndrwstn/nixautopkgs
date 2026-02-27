{ pkgs
, system
, opencodeInput
,
}:

let
  opencodeAssets = builtins.fromJSON (builtins.readFile ./assets.json);
  opencodeRouting = builtins.fromJSON (builtins.readFile ./routing.json);

  opencodeBin = import ./bin.nix {
    inherit pkgs system opencodeAssets;
  };

  routeForSystem = opencodeRouting.${system}
    or (throw "opencode routing: unsupported system ${system}");

  opencodeCliBuild = opencodeInput.packages.${system}.default;
  opencodeDesktopBuild = opencodeInput.packages.${system}.desktop;

  opencodeCliBin = opencodeBin."opencode-cli-bin";
  opencodeDesktopBin = opencodeBin."opencode-desktop-bin";

  resolveRoute = target: buildPackage: binPackage:
    let
      route = routeForSystem.${target}
        or (throw "opencode routing: missing `${target}` route for ${system}");
    in
    if route == "build" then buildPackage
    else if route == "bin" then binPackage
    else throw "opencode routing: invalid route `${route}` for ${system}.${target}";
in
{
  opencode-cli-build = opencodeCliBuild;
  opencode-desktop-build = opencodeDesktopBuild;
  opencode-cli-bin = opencodeCliBin;
  opencode-desktop-bin = opencodeDesktopBin;

  opencode = resolveRoute "cli" opencodeCliBuild opencodeCliBin;
  opencode-desktop = resolveRoute "desktop" opencodeDesktopBuild opencodeDesktopBin;
}
