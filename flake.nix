{
  description = "Profian Inc Network Infrastructure";

  inputs.benefice-production.url = github:profianinc/benefice/v0.1.2-rc6;
  inputs.benefice-staging.url = github:profianinc/benefice/v0.1.2-rc6;
  inputs.benefice-testing.url = github:profianinc/benefice;
  inputs.deploy-rs.inputs.flake-compat.follows = "flake-compat";
  inputs.deploy-rs.url = github:serokell/deploy-rs;
  inputs.enarx.url = github:enarx/enarx/v0.7.0;
  inputs.flake-compat.flake = false;
  inputs.flake-compat.url = github:edolstra/flake-compat;
  inputs.flake-utils.url = github:numtide/flake-utils;
  inputs.nixlib.url = github:nix-community/nixpkgs.lib;
  inputs.nixpkgs-stable.url = github:nixos/nixpkgs/release-22.05;
  inputs.nixpkgs-unstable.url = github:nixos/nixpkgs/nixos-unstable;
  inputs.nixpkgs.url = github:profianinc/nixpkgs;
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.url = github:Mic92/sops-nix;

  outputs = inputs @ {
    self,
    deploy-rs,
    flake-utils,
    nixpkgs,
    nixpkgs-stable,
    nixpkgs-unstable,
    ...
  }:
    {
      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
      deploy = import ./deploy inputs;
      lib = import ./lib inputs;
      nixosConfigurations = import ./nixosConfigurations inputs;
      nixosModules = import ./nixosModules inputs;
      overlays = import ./overlays inputs;
    }
    // flake-utils.lib.eachDefaultSystem (
      system: let
        pkgsStable = import nixpkgs-stable {
          inherit system;
        };

        pkgsUnstable = import nixpkgs-unstable {
          inherit system;
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (_: _: pkgsStable) # Overlay latest packages from "stable" upstream release channel
            (_: _: {
              # Overlay some latest packages from "unstable" upstream release channel
              inherit
                (pkgsUnstable)
                linux-firmware
                ;
            })
            self.overlays.default
          ];
        };

        devShells.base = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixUnstable
            openssh

            deploy-rs.packages.${system}.default
          ];
        };

        devShells.default = devShells.base.overrideAttrs (attrs: {
          buildInputs = with pkgs;
            attrs.buildInputs
            ++ [
              age
              awscli2
              openssl
              sops
              ssh-to-age
              tailscale

              bootstrap
              bootstrap-ca
              bootstrap-steward
              host-key
              ssh-for-each
            ];
        });
      in {
        inherit devShells;

        formatter = pkgs.alejandra;
      }
    );
}
