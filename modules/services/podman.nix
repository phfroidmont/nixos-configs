{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.services.podman;
in
{
  options.modules.services.podman = {
    enable = lib.mkEnableOption "Podman";
  };

  config = lib.mkIf cfg.enable {

    virtualisation = {
      podman = {
        enable = true;
        autoPrune.enable = true;
        # Provide the `docker` command. It runs rootless like `podman`.
        dockerCompat = true;
        # Let containers on the same compose network resolve each other by name.
        defaultNetwork.settings.dns_enabled = true;
      };
    };

    # Point Docker tooling (docker-compose, testcontainers, ...) at the per-user rootless socket.
    # Joining the podman group instead would grant root through the rootful socket.
    environment.variables.DOCKER_HOST = "unix://$XDG_RUNTIME_DIR/podman/podman.sock";

    environment.systemPackages = with pkgs; [ docker-compose ];

  };
}
