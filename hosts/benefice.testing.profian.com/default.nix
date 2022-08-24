{modulesPath, ...}: {
  imports = [
    "${modulesPath}/virtualisation/amazon-image.nix"

    ../../inventory/groups/meta/common.nix
  ];
}
