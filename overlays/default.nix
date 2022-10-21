inputs @ {nixlib, ...}: rec {
  service = import ./service.nix inputs;
  tooling = import ./tooling inputs;
  nixpkgs = import ./nixpkgs.nix inputs;

  default = nixlib.lib.composeManyExtensions [
    nixpkgs
    service
    tooling
  ];
}
