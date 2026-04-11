{
  lib,
  pkgs,
  ...
}:
let
  lanBridge = "br-lan";
in
{
  services.dnsmasq = {
    enable = true;
    settings = {
      interface = lanBridge;
      port = 54;
      "bind-interfaces" = true;
      "listen-address" = [
        "127.0.0.1"
        "192.168.1.1"
      ];
      "domain-needed" = true;
      "bogus-priv" = true;
      "no-resolv" = true;
      server = [
        "9.9.9.10"
        "1.1.1.1"
      ];
      domain = "lan";
      local = "/lan/";
      "expand-hosts" = true;
      "cache-size" = 1000;
      "dhcp-range" = [ "192.168.1.100,192.168.1.199,255.255.255.0,24h" ];
      "dhcp-option" = [
        "option:router,192.168.1.1"
        "option:dns-server,192.168.1.1"
        "option:domain-search,lan"
      ];
      "dhcp-authoritative" = true;
    };
  };

  services.adguardhome = {
    enable = true;
    openFirewall = false;
    mutableSettings = false;
    host = "192.168.1.1";
    port = 3000;
    settings = {
      auth_attempts = 5;
      block_auth_min = 15;
      dns = {
        bind_hosts = [
          "127.0.0.1"
          "192.168.1.1"
        ];
        port = 53;
        statistics_interval = 365;
        upstream_dns = [
          "tls://doh.mullvad.net"
          "[/lan/]127.0.0.1:54"
          "[//]127.0.0.1:54"
        ];
        local_ptr_upstreams = [ "127.0.0.1:54" ];
        use_private_ptr_resolvers = true;
        resolve_clients = true;
        bootstrap_dns = [ "9.9.9.10" ];
      };
      querylog = {
        enabled = true;
        interval = "8760h";
      };
    };
  };

  systemd.services.adguardhome = {
    unitConfig.ConditionPathExists = "/etc/secrets/aegis-adguard-admin-password-hash";
    preStart = lib.mkAfter ''
      ADMIN_HASH_FILE=/etc/secrets/aegis-adguard-admin-password-hash
      ADMIN_HASH="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$ADMIN_HASH_FILE")"

      if [[ -z "$ADMIN_HASH" ]]; then
        echo "AdGuard admin hash file is empty: $ADMIN_HASH_FILE" >&2
        exit 1
      fi

      cat > /run/AdGuardHome/admin-user.yaml <<EOF
      users:
        - name: admin
          password: $ADMIN_HASH
      EOF

      ${pkgs.yaml-merge}/bin/yaml-merge "$STATE_DIRECTORY/AdGuardHome.yaml" /run/AdGuardHome/admin-user.yaml > "$STATE_DIRECTORY/AdGuardHome.yaml.tmp"
      mv "$STATE_DIRECTORY/AdGuardHome.yaml.tmp" "$STATE_DIRECTORY/AdGuardHome.yaml"
      chmod 600 "$STATE_DIRECTORY/AdGuardHome.yaml"
    '';
  };
}
