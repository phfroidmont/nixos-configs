{ pkgs, ... }:
let
  lanBridge = "br-lan";
  mullvadGatewayScript = pkgs.writeShellScriptBin "mullvad-gw" ''
    set -euo pipefail

    WG_IF="mullvad"
    WG_UNIT="wg-quick-''${WG_IF}.service"
    LAN_IF="${lanBridge}"
    KILLSWITCH_CHAIN="nixos-filter-forward"
    SERVER_DIR="/etc/secrets/mullvad/servers"
    CURRENT_LINK="/etc/secrets/mullvad/current.conf"
    RUNTIME_CONF="/etc/secrets/mullvad/current-ipv4.conf"
    WG_MTU="1280"

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

    mss_rule_exists() {
      ${pkgs.iptables}/bin/iptables -t mangle -C FORWARD -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1
    }

    mss_enable() {
      if ! mss_rule_exists; then
        ${pkgs.iptables}/bin/iptables -t mangle -I FORWARD 1 -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      fi
    }

    mss_disable() {
      while mss_rule_exists; do
        ${pkgs.iptables}/bin/iptables -t mangle -D FORWARD -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
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

      ${pkgs.gnused}/bin/sed -i '/^[[:space:]]*MTU[[:space:]]*=/d' "$RUNTIME_CONF"
      ${pkgs.gnused}/bin/sed -i '0,/^\[Interface\]$/s//[Interface]\nMTU = '"$WG_MTU"'/' "$RUNTIME_CONF"

      ${pkgs.coreutils}/bin/chmod 0600 "$RUNTIME_CONF"
      ${pkgs.coreutils}/bin/chown root:root "$RUNTIME_CONF"
    }

    command="''${1:-status}"

    case "$command" in
      up)
        ensure_current_conf
        render_runtime_conf
        ks_enable
        mss_enable
        ${pkgs.systemd}/bin/systemctl restart "$WG_UNIT"
        ${pkgs.systemd}/bin/systemctl --no-pager --full status "$WG_UNIT"
        ;;

      down)
        ks_disable
        mss_disable
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
          mss_enable
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

        if mss_rule_exists; then
          echo "mss-clamp: enabled"
        else
          echo "mss-clamp: disabled"
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
  networking.wg-quick.interfaces.mullvad = {
    autostart = false;
    configFile = "/etc/secrets/mullvad/current-ipv4.conf";
  };

  environment.systemPackages = [
    mullvadGatewayScript
  ];
}
