# OpenCode v2 (beta channel) — bin-only package set.
#
# See ./bin.nix for the full rationale: upstream's release artifacts cannot be
# reproduced byte-for-byte (timestamped Developer ID signatures, electron-builder
# notarization, Sentry injection), so instead of shipping a nonfunctioning
# source build we always consume the prebuilt binaries from the
# anomalyco/opencode-beta releases. There is deliberately no routing layer and
# no flake input here — a failed fetch or hash mismatch fails loudly.
#
# Outputs:
#   opencode2          -> CLI, installs `opencode2` (coexists with v1 `opencode`)
#   opencode-desktop-v2 -> Desktop app ("OpenCode Beta.app" / beta .desktop file)
{ pkgs
, system
,
}:

let
  opencodeV2Bin = import ./bin.nix { inherit pkgs system; };
in
{
  opencode2 = opencodeV2Bin."opencode-cli-bin";
  opencode-desktop-v2 = opencodeV2Bin."opencode-desktop-bin";
}
