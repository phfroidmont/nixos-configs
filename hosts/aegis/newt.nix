{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # A hostname target avoids advertising a route for clients' local router IP.
  networking.hosts."192.168.1.1" = [ "aegis-target.home.internal" ];

  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    gnupg.sshKeyPaths = [ ];
    secrets.newtAegisEnvironment = lib.mkIf config.services.newt.enable {
      sopsFile = ../../secrets/aegis-newt.enc.yml;
      key = "newt/environment";
      restartUnits = [ "newt.service" ];
    };
  };

  services.newt = {
    enable = true;
    package = pkgs.callPackage ../../packages/newt/package.nix { };
    environmentFile =
      if config.services.newt.enable then config.sops.secrets.newtAegisEnvironment.path else null;
    settings = {
      endpoint = "https://pangolin.banditlair.com";
      disable-ssh = true;
    };
    blueprint.private-resources.aegis-management = {
      name = "Aegis management";
      mode = "host";
      destination = "aegis-target.home.internal";
      alias = "aegis.home.internal";
      tcp-ports = "22,3000";
      udp-ports = "";
      disable-icmp = true;
      roles = [ "Personal" ];
      users = [ ];
    };
  };
}
