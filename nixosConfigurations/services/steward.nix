{
  self,
  flake-utils,
  sops-nix,
  ...
}:
with flake-utils.lib.system; let
  mkSteward = self.lib.hosts.mkService [
    sops-nix.nixosModules.sops
    ({
      config,
      pkgs,
      ...
    }: {
      services.steward.certFile = pkgs.writeText "steward.crt" (builtins.readFile "${self}/hosts/${config.networking.fqdn}/steward.crt");
      services.steward.enable = true;
      services.steward.keyFile = config.sops.secrets.key.path;

      sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
      sops.secrets.key.format = "binary";
      sops.secrets.key.mode = "0000";
      sops.secrets.key.restartUnits = ["steward.service"];
      sops.secrets.key.sopsFile = "${self}/hosts/${config.networking.fqdn}/steward.key";

      systemd.services.steward = self.lib.systemd.withSecret config pkgs "steward" "key";

      # Workaround for https://github.com/profianinc/infrastructure/issues/109

      users.groups.steward = {};

      users.users.steward.isSystemUser = true;
      users.users.steward.group = config.users.groups.steward.name;
    })
  ];

  attest-testing = mkSteward x86_64-linux [
    ({pkgs, ...}: {
      imports = [
        "${self}/hosts/attest.testing.profian.com"
        "${self}/nixosModules/ci.nix"
      ];

      services.steward.log.level = "debug";
      services.steward.package = pkgs.steward.testing;
    })
  ];

  attest-staging = mkSteward x86_64-linux [
    ({pkgs, ...}: {
      imports = [
        "${self}/hosts/attest.staging.profian.com"
        "${self}/nixosModules/ci.nix"
      ];

      services.steward.log.level = "info";
      services.steward.package = pkgs.steward.staging;
    })
  ];

  attest = mkSteward x86_64-linux [
    ({pkgs, ...}: {
      imports = [
        "${self}/hosts/attest.profian.com"
      ];

      services.steward.package = pkgs.steward.production;
    })
  ];
in {
  inherit
    attest
    attest-staging
    attest-testing
    ;
}
