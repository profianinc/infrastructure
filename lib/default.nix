{
  self,
  nixpkgs,
  ...
}: {
  exposeKey = pkgs: user: key:
    pkgs.writeShellScript "expose-${key}.sh" ''
      chmod 0400 "${key}"
      chown ${user}:${user} "${key}"
    '';

  hideKey = pkgs: user: key:
    pkgs.writeShellScript "hide-${key}.sh" ''
      chmod 0000 "${key}"
      chown ${user}:${user} "${key}"
    '';

  mkService = base: system: extraModules:
    nixpkgs.lib.nixosSystem {
      inherit system;

      modules =
        [
          self.nixosModules.common
          self.nixosModules.users
          ({...}: {
            networking.firewall.allowedTCPPorts = [
              80
              443
            ];

            nixpkgs.overlays = [self.overlays.service];
          })
        ]
        ++ base
        ++ extraModules;
    };
}
