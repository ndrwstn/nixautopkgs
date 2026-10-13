# OpenCode stable — bin-only package set.
#
# See ./bin.nix for the full rationale: upstream's release artifacts cannot be
# reproduced byte-for-byte (timestamped Developer ID signatures, electron-builder
# notarization, Sentry injection), so instead of shipping a nonfunctioning
# source build we always consume the prebuilt binaries from the
# official OpenCode release artifacts. There is deliberately no routing layer and
# no flake input here — a failed fetch or hash mismatch fails loudly.
#
# Outputs:
#   opencode          -> CLI
#   opencode-desktop  -> Desktop app
{ pkgs
, system
,
}:

let
  opencodeBin = import ./bin.nix { inherit pkgs system; };
in
{
  opencode = opencodeBin.opencode;
  opencode-desktop = opencodeBin.opencode-desktop;
}
