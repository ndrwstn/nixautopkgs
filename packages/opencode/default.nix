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

  # Upstream source build defaults OPENCODE_CHANNEL to "local", which causes
  # a channel-suffixed DB filename (opencode-local.db). Override to latest so
  # CLI and desktop share opencode.db when desktop is using release semantics.
  opencodeCliBuild = opencodeInput.packages.${system}.default.overrideAttrs (old: {
    env = (old.env or { }) // {
      OPENCODE_CHANNEL = "latest";
    };
    postFixup = (old.postFixup or "") + ''
            # Upstream wraps opencode with a binary wrapper, which leaves tmux showing
            # the hidden .opencode-wrapped path. Replace only the final launcher with
            # a tiny shell wrapper that preserves upstream PATH setup and argv[0].
            if [ -f "$out/bin/.opencode-wrapped" ]; then
              rm -f "$out/bin/opencode"
              cat > "$out/bin/opencode" <<EOF
      #!${pkgs.runtimeShell}
      export PATH="${pkgs.lib.makeBinPath ([ pkgs.ripgrep ] ++ pkgs.lib.optional pkgs.stdenvNoCC.hostPlatform.isDarwin pkgs.sysctl)}:\$PATH"
      exec -a opencode "$out/bin/.opencode-wrapped" "\$@"
      EOF
              chmod 755 "$out/bin/opencode"
            fi
    '';
  });
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
    else if route == null then throw "opencode-desktop is not available for ${system} in this version; upstream dropped ARM64 Linux desktop builds starting with v1.14.34"
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
