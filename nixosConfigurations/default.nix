{...} @ inputs: let
  ci = import ./ci.nix inputs;
  services = import ./services inputs;
in
  ci
  // services
