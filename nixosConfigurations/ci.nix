{
  self,
  flake-utils,
  nixpkgs,
  ...
}:
with flake-utils.lib.system; let
  mkCI = system: modules:
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules =
        [
          self.nixosModules.common
          self.nixosModules.users
          ({...}: {
            services.rathole.enable = true;
          })
        ]
        ++ modules;
    };

  nuc-1-ci = mkCI x86_64-linux [
    ({
      config,
      pkgs,
      ...
    }: {
      imports = [
        "${self}/hosts/nuc-1.ci.profian.com"
      ];
    })
  ];
in {
  inherit
    nuc-1-ci
    ;
}
