{
  self,
  deploy-rs,
  ...
}: let
  mkGenericNode = nixos: {
    hostname = nixos.config.networking.fqdn;
    profiles.system.path = deploy-rs.lib.${nixos.config.nixpkgs.system}.activate.nixos nixos;
    profiles.system.sshUser = "deploy";
    profiles.system.user = "root";
  };

  mkTailscaleNode = nixos: {
    hostname = nixos.config.networking.hostName;
    profiles.system.path = deploy-rs.lib.${nixos.config.nixpkgs.system}.activate.nixos nixos;
    profiles.system.sshUser = "deploy";
    profiles.system.user = "root";
  };
in {
  nodes.benefice-testing = mkGenericNode self.nixosConfigurations.benefice-testing;
  nodes.nuc-1 = mkTailscaleNode self.nixosConfigurations.nuc-1;
  nodes.sgx-equinix-try = mkGenericNode self.nixosConfigurations.sgx-equinix-try;
  nodes.snp-aws-try = mkGenericNode self.nixosConfigurations.snp-aws-try;
  nodes.snp-equinix-try = mkGenericNode self.nixosConfigurations.snp-equinix-try;
}
