{
  config,
  lib,
  pkgs,
  ...
}:
let
  wanInterface = "enp1s0";
  lanBridge = "br-lan";
  lanInterfaces = [
    "enp2s0"
    "enp3s0"
    "enp4s0"
  ];
  wifiPassphraseScript = pkgs.writeShellScript "hostapd-wpa-passphrase" ''
    set -euo pipefail

    HOSTAPD_CONFIG="$1"
    PASSFILE="/etc/secrets/aegis-wifi-passphrase"

    if [[ ! -r "$PASSFILE" ]]; then
      echo "missing WPA2 passphrase file: $PASSFILE" >&2
      exit 1
    fi

    passphrase="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$PASSFILE")"
    if (( ''${#passphrase} < 8 || ''${#passphrase} > 63 )); then
      echo "WPA2 passphrase must be 8..63 characters" >&2
      exit 1
    fi

    printf 'wpa_passphrase=%s\n' "$passphrase" >> "$HOSTAPD_CONFIG"
  '';

  mullvadGatewayScript = pkgs.writeShellScriptBin "mullvad-gw" ''
    set -euo pipefail

    WG_IF="mullvad"
    WG_UNIT="wg-quick-''${WG_IF}.service"
    LAN_IF="${lanBridge}"
    KILLSWITCH_CHAIN="nixos-filter-forward"
    SERVER_DIR="/etc/secrets/mullvad/servers"
    CURRENT_LINK="/etc/secrets/mullvad/current.conf"
    RUNTIME_CONF="/etc/secrets/mullvad/current-ipv4.conf"

    ks_rule_exists() {
      ${pkgs.iptables}/bin/iptables -C "$KILLSWITCH_CHAIN" -i "$LAN_IF" ! -o "$WG_IF" -j REJECT >/dev/null 2>&1
    }

    ks_enable() {
      if ! ks_rule_exists; then
        ${pkgs.iptables}/bin/iptables -I "$KILLSWITCH_CHAIN" 1 -i "$LAN_IF" ! -o "$WG_IF" -j REJECT
      fi
    }

    ks_disable() {
      while ks_rule_exists; do
        ${pkgs.iptables}/bin/iptables -D "$KILLSWITCH_CHAIN" -i "$LAN_IF" ! -o "$WG_IF" -j REJECT
      done
    }

    ensure_current_conf() {
      if [[ ! -r "$CURRENT_LINK" ]]; then
        echo "Missing Mullvad config symlink/file: $CURRENT_LINK" >&2
        echo "Expected server files in: $SERVER_DIR" >&2
        exit 1
      fi
    }

    render_runtime_conf() {
      src="$(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || echo "$CURRENT_LINK")"

      ${pkgs.coreutils}/bin/install -d -m 0755 /etc/secrets/mullvad

      ${pkgs.gawk}/bin/awk '
        function trim(s) {
          gsub(/^[ \t]+|[ \t]+$/, "", s)
          return s
        }

        function keep_ipv4_list(s,    n, i, out, p) {
          n = split(s, a, ",")
          out = ""
          for (i = 1; i <= n; i++) {
            p = trim(a[i])
            if (p != "" && index(p, ":") == 0) {
              if (out != "") out = out ","
              out = out p
            }
          }
          return out
        }

        {
          sub(/\r$/, "")

          if ($0 ~ /^[[:space:]]*Address[[:space:]]*=/) {
            split($0, parts, "=")
            kept = keep_ipv4_list(parts[2])
            if (kept != "") {
              print "Address = " kept
            }
            next
          }

          if ($0 ~ /^[[:space:]]*AllowedIPs[[:space:]]*=/) {
            split($0, parts, "=")
            kept = keep_ipv4_list(parts[2])
            if (kept != "") {
              print "AllowedIPs = " kept
            }
            next
          }

          print
        }
      ' "$src" | ${pkgs.coreutils}/bin/tee "$RUNTIME_CONF" >/dev/null

      ${pkgs.coreutils}/bin/chmod 0600 "$RUNTIME_CONF"
      ${pkgs.coreutils}/bin/chown root:root "$RUNTIME_CONF"
    }

    command="''${1:-status}"

    case "$command" in
      up)
        ensure_current_conf
        render_runtime_conf
        ks_enable
        ${pkgs.systemd}/bin/systemctl restart "$WG_UNIT"
        ${pkgs.systemd}/bin/systemctl --no-pager --full status "$WG_UNIT"
        ;;

      down)
        ks_disable
        ${pkgs.systemd}/bin/systemctl stop "$WG_UNIT"
        ;;

      switch)
        if [[ $# -lt 2 ]]; then
          echo "Usage: mullvad-gw switch <server-name>" >&2
          exit 1
        fi

        target="''${SERVER_DIR}/$2.conf"
        if [[ ! -r "$target" ]]; then
          echo "Unknown server '$2' (expected: $target)" >&2
          exit 1
        fi

        ${pkgs.coreutils}/bin/ln -sfn "$target" "$CURRENT_LINK"
        render_runtime_conf

        if ${pkgs.systemd}/bin/systemctl is-active --quiet "$WG_UNIT"; then
          ks_enable
          ${pkgs.systemd}/bin/systemctl restart "$WG_UNIT"
        fi

        ;;

      list)
        shopt -s nullglob
        files=("$SERVER_DIR"/*.conf)
        if (( ''${#files[@]} == 0 )); then
          echo "No server config files found under $SERVER_DIR" >&2
          exit 1
        fi

        current="$(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || true)"
        for file in "''${files[@]}"; do
          name="$(${pkgs.coreutils}/bin/basename "$file" .conf)"
          marker=" "
          if [[ "$file" == "$current" ]]; then
            marker="*"
          fi
          printf "%s %s\n" "$marker" "$name"
        done
        ;;

      status)
        if ${pkgs.systemd}/bin/systemctl is-active --quiet "$WG_UNIT"; then
          echo "mullvad: up"
        else
          echo "mullvad: down"
        fi

        if ks_rule_exists; then
          echo "killswitch: enabled"
        else
          echo "killswitch: disabled"
        fi

        if [[ -e "$CURRENT_LINK" ]]; then
          echo "current config: $(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || echo "$CURRENT_LINK")"
        else
          echo "current config: missing ($CURRENT_LINK)"
        fi

        if [[ -e "$RUNTIME_CONF" ]]; then
          echo "runtime config: $RUNTIME_CONF"
        else
          echo "runtime config: missing ($RUNTIME_CONF)"
        fi

        if ${pkgs.iproute2}/bin/ip link show "$WG_IF" >/dev/null 2>&1; then
          ${pkgs.wireguard-tools}/bin/wg show "$WG_IF" || true
        fi
        ;;

      *)
        echo "Usage: mullvad-gw <up|down|status|list|switch SERVER>" >&2
        exit 1
        ;;
    esac
  '';
in
{
  networking.hostName = "aegis";

  hardware = {
    enableRedistributableFirmware = true;
    wirelessRegulatoryDatabase = true;
  };

  networking = {
    useDHCP = false;
    interfaces.${wanInterface}.useDHCP = true;

    bridges.${lanBridge}.interfaces = lanInterfaces;

    interfaces.${lanBridge}.ipv4.addresses = [
      {
        address = "192.168.1.1";
        prefixLength = 24;
      }
    ];

    nameservers = [
      "127.0.0.1"
      "1.1.1.1"
    ];

    nat = {
      enable = true;
      externalInterface = lib.mkForce null;
      internalInterfaces = [ lanBridge ];
    };

    firewall = {
      enable = true;
      checkReversePath = "loose";
      interfaces.${lanBridge} = {
        allowedTCPPorts = [
          22
          53
          3000
        ];
        allowedUDPPorts = [
          53
          67
        ];
      };
    };
  };

  nix.settings.trusted-users = [
    "root"
    config.user.name
  ];

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

  services.hostapd = {
    enable = true;
    radios.wlan1 = {
      countryCode = "BE";
      band = "5g";
      channel = 36;
      wifi4.capabilities = [
        "HT40+"
        "SHORT-GI-20"
        "SHORT-GI-40"
      ];
      wifi5.operatingChannelWidth = "80";
      networks.wlan1 = {
        ssid = "NSA honeypot";
        authentication.mode = "none";
        settings = {
          bridge = lanBridge;
          vht_oper_centr_freq_seg0_idx = 42;
          wpa = 2;
          wpa_key_mgmt = "WPA-PSK";
          wpa_pairwise = "CCMP";
          rsn_pairwise = "CCMP";
        };
        dynamicConfigScripts."20-wpa-passphrase" = wifiPassphraseScript;
      };
    };

  };

  systemd.services.hostapd = {
    after = lib.mkForce [ "network.target" ];
    bindsTo = lib.mkForce [ ];
    unitConfig.ConditionPathExists = "/etc/secrets/aegis-wifi-passphrase";
  };

  networking.wg-quick.interfaces.mullvad = {
    autostart = false;
    configFile = "/etc/secrets/mullvad/current-ipv4.conf";
  };

  environment.systemPackages = [
    mullvadGatewayScript
  ];

  boot.kernel.sysctl."net.ipv4.ip_forward" = lib.mkForce 1;

  user = {
    name = "admin";
    description = lib.mkForce "Router administrator";
    extraGroups = [ "wheel" ];
    hashedPassword = "!";
    initialPassword = lib.mkForce null;
    openssh.authorizedKeys.keyFiles = [
      ../../ssh_keys/phfroidmont-desktop.pub
      ../../ssh_keys/phfroidmont-stellaris.pub
    ];
  };

  users.users.root.hashedPassword = "!";
  users.users.root.initialPassword = lib.mkForce null;
  security.sudo.wheelNeedsPassword = false;

  home-manager.useUserPackages = lib.mkForce false;
  home-manager.users = lib.mkForce { };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "xhci_pci"
    "usbhid"
    "sd_mod"
    "igc"
    "r8169"
    "e1000e"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/EFI";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ config.user.name ];
    };
  };

  system.stateVersion = "25.11";
}
