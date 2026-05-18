{ pkgs
, system
, opencodeInput
,
}:

let
  opencodeRuntimePath = pkgs.lib.makeBinPath ([ pkgs.ripgrep ] ++ pkgs.lib.optional pkgs.stdenvNoCC.hostPlatform.isDarwin pkgs.sysctl);
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
            # Upstream wraps opencode by renaming the real executable to
            # .opencode-wrapped. That leaves tmux on macOS showing the hidden
            # basename because it ignores argv[0] and uses the actual exec path.
            # Move the real executable to libexec/opencode and keep a small
            # launcher in bin/opencode so both tmux and ps see "opencode"
            # cross-platform.
            if [ -f "$out/bin/.opencode-wrapped" ]; then
              mkdir -p "$out/libexec"
              mv "$out/bin/.opencode-wrapped" "$out/libexec/opencode"
              rm -f "$out/bin/opencode"
              cat > "$out/bin/opencode" <<EOF
      #!${pkgs.runtimeShell}
      export PATH="${opencodeRuntimePath}:\$PATH"
      exec -a opencode "$out/libexec/opencode" "\$@"
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
