{
  nixlib,
  nixpkgs-stable,
  nixpkgs-unstable,
  ...
}:
nixlib.lib.composeManyExtensions [
  (final: _: nixpkgs-stable.legacyPackages.${final.system}) # Overlay latest packages from "stable" upstream release channel
  (final: _: {
    # Overlay some latest packages from "unstable" upstream release channel
    inherit
      (nixpkgs-unstable.legacyPackages.${final.system})
      linux-firmware
      ;
  })
]
