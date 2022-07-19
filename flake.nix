{
  description = "Profian Inc Network Infrastructure";

  inputs.benefice-staging.flake = false;
  inputs.benefice-staging.url = "https://github.com/profianinc/benefice/releases/download/v0.1.0-rc6/benefice-x86_64-unknown-linux-musl";
  inputs.benefice-testing.url = github:profianinc/benefice;
  inputs.deploy-rs.inputs.flake-compat.follows = "flake-compat";
  inputs.deploy-rs.url = github:serokell/deploy-rs;
  inputs.drawbridge-production.flake = false;
  inputs.drawbridge-production.url = "https://github.com/profianinc/drawbridge/releases/download/v0.2.0/drawbridge-x86_64-unknown-linux-musl";
  inputs.drawbridge-staging.flake = false;
  inputs.drawbridge-staging.url = "https://github.com/profianinc/drawbridge/releases/download/v0.2.0/drawbridge-x86_64-unknown-linux-musl";
  inputs.drawbridge-testing.url = github:profianinc/drawbridge;
  inputs.enarx.flake = false;
  # TODO: Use upstream release
  inputs.enarx.url = "https://github.com/rvolosatovs/enarx/releases/download/v0.6.1-rc1/enarx-x86_64-unknown-linux-musl";
  inputs.flake-compat.flake = false;
  inputs.flake-compat.url = github:edolstra/flake-compat;
  inputs.flake-utils.url = github:numtide/flake-utils;
  inputs.nixpkgs.url = github:profianinc/nixpkgs;
  inputs.sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  inputs.sops-nix.url = "github:Mic92/sops-nix";
  inputs.steward-production.flake = false;
  inputs.steward-production.url = "https://github.com/profianinc/steward/releases/download/v0.1.0/steward-x86_64-unknown-linux-musl";
  inputs.steward-staging.flake = false;
  inputs.steward-staging.url = "https://github.com/profianinc/steward/releases/download/v0.1.0/steward-x86_64-unknown-linux-musl";
  inputs.steward-testing.url = github:profianinc/steward;

  outputs = {
    self,
    benefice-staging,
    benefice-testing,
    deploy-rs,
    drawbridge-production,
    drawbridge-staging,
    drawbridge-testing,
    enarx,
    flake-compat,
    flake-utils,
    nixpkgs,
    sops-nix,
    steward-production,
    steward-staging,
    steward-testing,
  }: let
    sshUser = "deploy";

    emails.ops = "roman@profian.com"; # TODO: How about ops@profian.com ?

    oidc.client.demo.equinix.sgx = "23Lt09AjF8HpUeCCwlfhuV34e2dKD1MH";
    oidc.client.demo.equinix.snp = "Ayrct2YbMF6OHFN8bzpv3XemWI3ca5Hk";

    oidc.client.testing.benefice = "FTmeUMamlu8HRs11mvtmmZHnmCwRIo8E";
    oidc.client.testing.store = "zFrR7MKMakS4OpEflR0kNw3ceoP7sr3s";

    oidc.client.staging.store = "9SVWiB3sQQdzKqpZmMNvsb9rzd8Ha21F";

    oidc.client.production.store = "2vq9XnQgcGZ9JCxsGERuGURYIld3mcIh";

    serviceOverlay = self: super: let
      fromInput = name: src:
        self.stdenv.mkDerivation {
          inherit name;
          phases = ["installPhase"];
          installPhase = ''
            mkdir -p $out/bin
            install ${src} $out/bin/${name}
          '';
        };
    in {
      benefice.testing = benefice-testing.packages.x86_64-linux.benefice-debug-x86_64-unknown-linux-musl;
      benefice.staging = fromInput "benefice" benefice-staging;

      drawbridge.testing = drawbridge-testing.packages.x86_64-linux.drawbridge-debug-x86_64-unknown-linux-musl;
      drawbridge.staging = fromInput "drawbridge" drawbridge-staging;
      drawbridge.production = fromInput "drawbridge" drawbridge-production;

      enarx = fromInput "enarx" enarx;

      steward.testing = steward-testing.packages.x86_64-linux.steward-x86_64-unknown-linux-musl;
      steward.staging = fromInput "steward" steward-staging;
      steward.production = fromInput "steward" steward-production;
    };

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

    mkHost = system: modules:
      nixpkgs.lib.nixosSystem {
        inherit system;

        modules =
          [
            ./modules
            ({config, ...}: {
              networking.firewall.allowedTCPPorts = [
                80
                443
              ];

              nix.settings.allowed-users = with config.users; [
                "@${groups.deploy.name}"
              ];
              nix.settings.trusted-users = with config.users; [
                "@${groups.deploy.name}"
              ];
              nixpkgs.overlays = [serviceOverlay];

              security.acme.defaults.email = emails.ops;
            })
          ]
          ++ modules;
      };

    mkService = base: system: modules: mkHost system (base ++ modules);

    mkBenefice = mkService [
      sops-nix.nixosModules.sops
      ({
        config,
        lib,
        pkgs,
        ...
      }: {
        networking.firewall.enable = lib.mkForce false;

        services.benefice.enable = true;
        services.benefice.oidc.secretFile = config.sops.secrets.oidc-secret.path;

        sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        sops.secrets.oidc-secret.format = "binary";
        sops.secrets.oidc-secret.mode = "0000";
        sops.secrets.oidc-secret.restartUnits = ["benefice.service"];

        systemd.services.benefice.serviceConfig.ExecStartPre = "+${exposeKey pkgs "benefice" config.sops.secrets.oidc-secret.path}";
        systemd.services.benefice.serviceConfig.ExecStop = "+${hideKey pkgs config.users.users.root.name config.sops.secrets.oidc-secret.path}";
        systemd.services.benefice.serviceConfig.SupplementaryGroups = [config.users.groups.keys.name];
      })
    ];

    mkDrawbridge = mkService [
      {
        services.drawbridge.enable = true;
        services.drawbridge.tls.caFile = "${./ca/ca.crt}";
      }
    ];

    mkSteward = mkService [
      sops-nix.nixosModules.sops
      ({
        config,
        pkgs,
        ...
      }: {
        services.steward.enable = true;
        services.steward.keyFile = config.sops.secrets.key.path;

        sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
        sops.secrets.key.format = "binary";
        sops.secrets.key.mode = "0000";
        sops.secrets.key.restartUnits = ["steward.service"];

        systemd.services.steward.serviceConfig.ExecStartPre = "+${exposeKey pkgs "steward" config.sops.secrets.key.path}";
        systemd.services.steward.serviceConfig.ExecStop = "+${hideKey pkgs config.users.users.root.name config.sops.secrets.key.path}";
        systemd.services.steward.serviceConfig.SupplementaryGroups = [config.users.groups.keys.name];
      })
    ];

    hostKey = pkgs: let
      grep = "${pkgs.gnugrep}/bin/grep";
      ssh-keyscan = "${pkgs.openssh}/bin/ssh-keyscan";
      ssh-to-age = "${pkgs.ssh-to-age}/bin/ssh-to-age";
    in
      pkgs.writeShellScriptBin "host-key" ''
        set -e

        ${ssh-keyscan} "''${1}" 2> /dev/null | ${grep} 'ssh-ed25519' | ${ssh-to-age}
      '';

    bootstrapCA = pkgs: let
      conf = pkgs.writeText "ca.conf" ''
        [req]
        distinguished_name = req_distinguished_name
        prompt = no
        x509_extensions = v3_ca

        [req_distinguished_name]
        C   = US
        ST  = North Carolina
        L   = Raleigh
        CN  = Proof of Concept

        [v3_ca]
        basicConstraints = critical,CA:TRUE
        keyUsage = cRLSign, keyCertSign
        nsComment = "Profian CA certificate"
        subjectKeyIdentifier = hash
      '';

      openssl = "${pkgs.openssl}/bin/openssl";
      sops = "${pkgs.sops}/bin/sops";
    in
      pkgs.writeShellScriptBin "bootstrap-ca" ''
        set -e

        umask 0077

        ${openssl} ecparam -genkey -name prime256v1 | ${openssl} pkcs8 -topk8 -nocrypt -out ca/ca.key
        ${openssl} req -new -x509 -days 365 -config ${conf} -key ca/ca.key -out ca/ca.crt
        ${sops} -e -i ca/ca.key
      '';

    bootstrapSteward = pkgs: let
      key = ''"''${1}/ca.key"'';
      csr = ''"''${1}/ca.csr"'';
      crt = ''"''${1}/ca.crt"'';

      conf = ./ca/ca.conf;
      openssl = "${pkgs.openssl}/bin/openssl";
      shred = "${pkgs.coreutils}/bin/shred";
      sops = "${pkgs.sops}/bin/sops";
    in
      pkgs.writeShellScriptBin "bootstrap-steward" ''
        set -e

        umask 0077

        ${openssl} ecparam -genkey -name prime256v1 | ${openssl} pkcs8 -topk8 -nocrypt -out ${key}
        ${openssl} req -new -config ${conf} -key ${key} -out ${csr}

        ${sops} -d ca/ca.key > ca/ca.plaintext.key
        ${openssl} x509 -req -days 365 -CAcreateserial -CA ca/ca.crt -CAkey ca/ca.plaintext.key -in ${csr} -out ${crt} -extfile ${conf} -extensions v3_ca

        ${shred} -fzu ca/ca.plaintext.key
        ${sops} -e -i ${key}
      '';

    bootstrap = pkgs: let
      bootstrap-steward = "${pkgs.bootstrap-steward}/bin/bootstrap-steward";
    in
      pkgs.writeShellScriptBin "bootstrap" ''
        for host in hosts/attest.*; do
            ${bootstrap-steward} "''${host}"
        done
      '';

    toolingOverlay = self: super: {
      host-key = hostKey self;
      bootstrap-ca = bootstrapCA self;
      bootstrap-steward = bootstrapSteward self;
      bootstrap = bootstrap self;
    };
  in
    {
      nixosConfigurations = {
        sgx-equinix-demo = mkBenefice "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/sgx.equinix.demo.enarx.dev
            ];

            services.benefice.log.level = "info";
            services.benefice.oidc.client = oidc.client.demo.equinix.sgx;
            services.benefice.package = pkgs.benefice.staging;

            sops.secrets.oidc-secret.sopsFile = ./hosts/sgx.equinix.demo.enarx.dev/oidc-secret;
          })
        ];

        snp-equinix-demo = mkBenefice "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/snp.equinix.demo.enarx.dev
            ];

            services.benefice.log.level = "info";
            services.benefice.oidc.client = oidc.client.demo.equinix.snp;
            services.benefice.package = pkgs.benefice.staging;

            sops.secrets.oidc-secret.sopsFile = ./hosts/snp.equinix.demo.enarx.dev/oidc-secret;
          })
        ];

        attest-staging = mkSteward "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/attest.staging.profian.com
            ];

            services.steward.certFile = "${./hosts/attest.staging.profian.com/ca.crt}";
            services.steward.log.level = "info";
            services.steward.package = pkgs.steward.staging;

            sops.secrets.key.sopsFile = ./hosts/attest.staging.profian.com/ca.key;
          })
        ];

        attest-testing = mkSteward "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/attest.testing.profian.com
            ];

            services.steward.certFile = "${./hosts/attest.testing.profian.com/ca.crt}";
            services.steward.log.level = "debug";
            services.steward.package = pkgs.steward.testing;

            sops.secrets.key.sopsFile = ./hosts/attest.testing.profian.com/ca.key;
          })
        ];

        attest = mkSteward "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/attest.profian.com
            ];

            services.steward.certFile = "${./hosts/attest.profian.com/ca.crt}";
            services.steward.package = pkgs.steward.production;

            sops.secrets.key.sopsFile = ./hosts/attest.profian.com/ca.key;
          })
        ];

        store-testing = mkDrawbridge "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/store.testing.profian.com
            ];

            services.drawbridge.log.level = "debug";
            services.drawbridge.oidc.client = oidc.client.testing.store;
            services.drawbridge.package = pkgs.drawbridge.testing;
          })
        ];

        store-staging = mkDrawbridge "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/store.staging.profian.com
            ];

            services.drawbridge.log.level = "info";
            services.drawbridge.oidc.client = oidc.client.staging.store;
            services.drawbridge.package = pkgs.drawbridge.staging;
          })
        ];

        store = mkDrawbridge "x86_64-linux" [
          ({pkgs, ...}: {
            imports = [
              ./hosts/store.profian.com
            ];

            services.drawbridge.oidc.client = oidc.client.production.store;
            services.drawbridge.package = pkgs.drawbridge.production;
          })
        ];
      };

      deploy.nodes = let
        mkNode = system: name: {
          hostname = self.nixosConfigurations.${name}.config.networking.fqdn;
          profiles.system.path = deploy-rs.lib.${system}.activate.nixos self.nixosConfigurations.${name};
          profiles.system.sshUser = sshUser;
          profiles.system.user = "root";
        };

        mkX86_64LinuxNode = mkNode "x86_64-linux";
      in {
        sgx-equinix-demo = mkX86_64LinuxNode "sgx-equinix-demo";
        snp-equinix-demo = mkX86_64LinuxNode "snp-equinix-demo";

        attest = mkX86_64LinuxNode "attest";
        attest-staging = mkX86_64LinuxNode "attest-staging";
        attest-testing = mkX86_64LinuxNode "attest-testing";

        store = mkX86_64LinuxNode "store";
        store-staging = mkX86_64LinuxNode "store-staging";
        store-testing = mkX86_64LinuxNode "store-testing";
      };

      checks = builtins.mapAttrs (system: deployLib: deployLib.deployChecks self.deploy) deploy-rs.lib;
    }
    // flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [
          serviceOverlay
          toolingOverlay
        ];
      };
    in {
      formatter = pkgs.alejandra;

      devShells.default = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.age
          pkgs.nixUnstable
          pkgs.openssl
          pkgs.sops
          pkgs.ssh-to-age

          pkgs.bootstrap
          pkgs.bootstrap-ca
          pkgs.bootstrap-steward
          pkgs.host-key

          deploy-rs.packages.${system}.default
        ];
      };
    });
}
