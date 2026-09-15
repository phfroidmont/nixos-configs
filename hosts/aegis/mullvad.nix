{ pkgs, ... }:
let
  lanBridge = "br-lan";
  fetchMetadata = pkgs.writeScript "mullvad-fetch-metadata" (
    builtins.readFile ./mullvad/fetch_metadata.py
  );
  profileTool = pkgs.writeScript "mullvad-profiles" (builtins.readFile ./mullvad/profiles.py);
  healthTool = pkgs.writeScript "mullvad-health" (builtins.readFile ./mullvad/health.py);
  mullvadGatewayScript = pkgs.writeShellScriptBin "mullvad-gw" ''
    set -euo pipefail
    umask 077

    WG_IF="mullvad"
    WG_UNIT="''${MULLVAD_WG_UNIT:-wg-quick-''${WG_IF}.service}"
    LAN_IF="${lanBridge}"
    KILLSWITCH_CHAIN="nixos-filter-forward"
    BASE_DIR="''${MULLVAD_BASE_DIR:-/etc/secrets/mullvad}"
    SERVER_DIR="$BASE_DIR/servers"
    CURRENT_LINK="$BASE_DIR/current.conf"
    RUNTIME_CONF="$BASE_DIR/current-ipv4.conf"
    IDENTITY_FILE="$BASE_DIR/identity.conf"
    COUNTRY_FILE="$BASE_DIR/current-country"
    LOCK_FILE="''${MULLVAD_LOCK_FILE:-/run/lock/mullvad-gw.lock}"
    LOCK_TIMEOUT="''${MULLVAD_LOCK_TIMEOUT:-120}"
    SYSTEMCTL="''${MULLVAD_SYSTEMCTL:-${pkgs.systemd}/bin/systemctl}"
    IPTABLES="''${MULLVAD_IPTABLES:-${pkgs.iptables}/bin/iptables}"
    FETCH_METADATA="''${MULLVAD_FETCH_METADATA:-${fetchMetadata}}"
    FILE_OWNER="''${MULLVAD_FILE_OWNER:-root}"
    FILE_GROUP="''${MULLVAD_FILE_GROUP:-root}"
    WG_MTU="1280"
    TCP_MSS="$((WG_MTU - 40))"

    ks_rule_exists() {
      "$IPTABLES" -C "$KILLSWITCH_CHAIN" -i "$LAN_IF" ! -o "$WG_IF" -j REJECT >/dev/null 2>&1
    }

    ks_enable() {
      if ! ks_rule_exists; then
        "$IPTABLES" -I "$KILLSWITCH_CHAIN" 1 -i "$LAN_IF" ! -o "$WG_IF" -j REJECT
      fi
    }

    ks_disable() {
      while ks_rule_exists; do
        "$IPTABLES" -D "$KILLSWITCH_CHAIN" -i "$LAN_IF" ! -o "$WG_IF" -j REJECT
      done
    }

    mss_out_rule_exists() {
      "$IPTABLES" -t mangle -C FORWARD -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu >/dev/null 2>&1
    }

    mss_in_rule_exists() {
      "$IPTABLES" -t mangle -C FORWARD -i "$WG_IF" -o "$LAN_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$TCP_MSS" >/dev/null 2>&1
    }

    mss_rule_exists() {
      mss_out_rule_exists && mss_in_rule_exists
    }

    mss_enable() {
      if ! mss_out_rule_exists; then
        "$IPTABLES" -t mangle -I FORWARD 1 -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      fi
      if ! mss_in_rule_exists; then
        "$IPTABLES" -t mangle -I FORWARD 1 -i "$WG_IF" -o "$LAN_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$TCP_MSS"
      fi
    }

    mss_disable() {
      while mss_out_rule_exists; do
        "$IPTABLES" -t mangle -D FORWARD -i "$LAN_IF" -o "$WG_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
      done
      while mss_in_rule_exists; do
        "$IPTABLES" -t mangle -D FORWARD -i "$WG_IF" -o "$LAN_IF" -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --set-mss "$TCP_MSS"
      done
    }

    ensure_base_dir() {
      ${pkgs.coreutils}/bin/install -d -o "$FILE_OWNER" -g "$FILE_GROUP" -m 0700 "$BASE_DIR"
    }

    ensure_current_conf() {
      if [[ ! -r "$CURRENT_LINK" ]]; then
        echo "Missing Mullvad config symlink/file: $CURRENT_LINK" >&2
        echo "Run 'mullvad-gw refresh' after placing an existing config at that path." >&2
        exit 1
      fi
    }

    ensure_identity() {
      if [[ -r "$IDENTITY_FILE" ]]; then
        return
      fi
      ensure_current_conf
      source_conf="$(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || echo "$CURRENT_LINK")"
      ${pkgs.python3}/bin/python3 ${profileTool} migrate "$source_conf" "$IDENTITY_FILE"
      ${pkgs.coreutils}/bin/chown "$FILE_OWNER:$FILE_GROUP" "$IDENTITY_FILE"
      ${pkgs.coreutils}/bin/chmod 0600 "$IDENTITY_FILE"
      echo "Migrated Mullvad device identity to $IDENTITY_FILE"
    }

    render_runtime_conf() {
      src="$(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || echo "$CURRENT_LINK")"
      temporary="$BASE_DIR/.current-ipv4.$$"
      trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT RETURN

      ${pkgs.gawk}/bin/awk -v mtu="$WG_MTU" '
        function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
        function keep_ipv4_list(s,    n, i, out, p) {
          n = split(s, a, ","); out = ""
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
          if (tolower(trim($0)) == "[interface]") {
            print "[Interface]"
            if (!found_interface) {
              print "FwMark = 51820"
              print "MTU = " mtu
              found_interface = 1
            }
            next
          }
          equals = index($0, "=")
          if (equals) {
            key = tolower(trim(substr($0, 1, equals - 1)))
            if (key == "address" || key == "allowedips" || key == "dns") {
              kept = keep_ipv4_list(substr($0, equals + 1))
              if (kept != "") {
                if (key == "address") print "Address = " kept
                else if (key == "allowedips") print "AllowedIPs = " kept
                else print "DNS = " kept
              }
              next
            }
            if (key == "mtu" || key == "fwmark") next
          }
          print
        }
        END {
          if (!found_interface) {
            print "Mullvad config is missing an [Interface] section" > "/dev/stderr"
            exit 1
          }
        }
      ' "$src" > "$temporary"

      ${pkgs.coreutils}/bin/chown "$FILE_OWNER:$FILE_GROUP" "$temporary"
      ${pkgs.coreutils}/bin/chmod 0600 "$temporary"
      ${pkgs.coreutils}/bin/mv -f "$temporary" "$RUNTIME_CONF"
      trap - EXIT RETURN
    }

    check_health() {
      if [[ -n "''${MULLVAD_HEALTH_COMMAND:-}" ]]; then
        "$MULLVAD_HEALTH_COMMAND"
        return
      fi
      health_target="$(${pkgs.gawk}/bin/awk -F= '
        tolower($1) ~ /^[[:space:]]*dns[[:space:]]*$/ {
          gsub(/[[:space:]]/, "", $2)
          split($2, addresses, ",")
          if (addresses[1] !~ /:/) { print addresses[1]; exit }
        }
      ' "$RUNTIME_CONF" 2>/dev/null || true)"
      health_target="''${health_target:-10.64.0.1}"
      deadline=$((SECONDS + 15))
      while (( SECONDS < deadline )); do
        ${pkgs.iputils}/bin/ping -n -I "$WG_IF" -c 1 -W 2 "$health_target" >/dev/null 2>&1 || true
        handshake="$(${pkgs.wireguard-tools}/bin/wg show "$WG_IF" latest-handshakes 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR == 1 { print $2 + 0 }')"
        transfers="$(${pkgs.wireguard-tools}/bin/wg show "$WG_IF" transfer 2>/dev/null | ${pkgs.gawk}/bin/awk 'NR == 1 { print ($2 + 0), ($3 + 0) }')"
        read -r received sent <<< "''${transfers:-0 0}"
        now="$(${pkgs.coreutils}/bin/date +%s)"
        if ${pkgs.python3}/bin/python3 ${healthTool} "''${handshake:-0}" "$received" "$sent" "$now"; then
          return 0
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
      return 1
    }

    restart_and_check() {
      "$SYSTEMCTL" restart "$WG_UNIT"
      if ! check_health; then
        echo "Mullvad tunnel started, but handshake/traffic health check failed; kill switch remains enabled" >&2
        return 2
      fi
    }

    refresh_profiles() {
      ensure_base_dir
      ensure_identity
      metadata="$BASE_DIR/.metadata.$$"
      stage="$BASE_DIR/.servers.$(${pkgs.coreutils}/bin/date +%s).$$"
      link_tmp="$BASE_DIR/.servers-link.$$"
      trap '${pkgs.coreutils}/bin/rm -f "$metadata" "$link_tmp" "$BASE_DIR/.current.$$" "$BASE_DIR/.country.$$"; ${pkgs.coreutils}/bin/rm -rf "$stage"' EXIT RETURN

      MULLVAD_CA_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt \
        ${pkgs.python3}/bin/python3 "$FETCH_METADATA" > "$metadata"
      preferred=""
      if [[ -e "$CURRENT_LINK" ]]; then
        preferred="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK" 2>/dev/null || true)" .conf)"
      fi
      country=""
      if [[ -r "$COUNTRY_FILE" ]]; then
        country="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "$COUNTRY_FILE")"
      elif [[ "$preferred" =~ ^[a-z]{2}- ]]; then
        # Seed the persistent choice during migration from the selected hostname.
        country="''${preferred%%-*}"
      fi
      result="$(${pkgs.python3}/bin/python3 ${profileTool} generate "$metadata" "$IDENTITY_FILE" "$stage" --preferred "$preferred" --country "$country")"
      selected="$(${pkgs.jq}/bin/jq -er '.hostname' <<< "$result")"
      selected_country="$(${pkgs.jq}/bin/jq -er '.country' <<< "$result")"
      count="$(${pkgs.jq}/bin/jq -er '.count' <<< "$result")"

      changed=1
      if [[ -r "$CURRENT_LINK" ]] && ${pkgs.diffutils}/bin/cmp -s "$CURRENT_LINK" "$stage/$selected.conf"; then
        changed=0
      fi
      old_generation=""
      if [[ -L "$SERVER_DIR" ]]; then
        old_generation="$(${pkgs.coreutils}/bin/readlink -f "$SERVER_DIR" 2>/dev/null || true)"
      elif [[ -d "$SERVER_DIR" ]]; then
        legacy="$BASE_DIR/servers.pre-refresh.$(${pkgs.coreutils}/bin/date +%s)"
        ${pkgs.coreutils}/bin/mv "$SERVER_DIR" "$legacy"
        echo "Preserved previous server directory at $legacy"
      fi
      ${pkgs.coreutils}/bin/ln -s "$stage" "$link_tmp"
      ${pkgs.coreutils}/bin/mv -Tf "$link_tmp" "$SERVER_DIR"
      # The staged generation is now published and must not be removed on a later error.
      stage=""
      ${pkgs.coreutils}/bin/ln -s "$SERVER_DIR/$selected.conf" "$BASE_DIR/.current.$$"
      ${pkgs.coreutils}/bin/mv -Tf "$BASE_DIR/.current.$$" "$CURRENT_LINK"
      printf '%s\n' "$selected_country" > "$BASE_DIR/.country.$$"
      ${pkgs.coreutils}/bin/chmod 0600 "$BASE_DIR/.country.$$"
      ${pkgs.coreutils}/bin/mv -f "$BASE_DIR/.country.$$" "$COUNTRY_FILE"
      ${pkgs.coreutils}/bin/rm -f "$metadata"
      if [[ "$old_generation" == "$BASE_DIR"/.servers.* && -d "$old_generation" ]]; then
        ${pkgs.coreutils}/bin/rm -rf "$old_generation"
      fi
      trap - EXIT RETURN

      echo "Installed $count active Mullvad profiles; selected $selected ($selected_country)"
      active=0
      if "$SYSTEMCTL" is-active --quiet "$WG_UNIT"; then
        active=1
      fi
      if (( changed )); then
        render_runtime_conf
      fi
      if (( active )); then
        ks_enable
        mss_enable
        if (( changed )); then
          restart_and_check
        fi
      fi
    }

    command="''${1:-status}"
    case "$command" in
      up|down|switch|refresh)
        lock_dir="$(${pkgs.coreutils}/bin/dirname "$LOCK_FILE")"
        if [[ ! -d "$lock_dir" ]]; then
          ${pkgs.coreutils}/bin/install -d -m 0755 "$lock_dir"
        fi
        exec 9>"$LOCK_FILE"
        if ! ${pkgs.util-linux}/bin/flock -w "$LOCK_TIMEOUT" 9; then
          echo "Timed out after $LOCK_TIMEOUT seconds waiting for another mullvad-gw operation" >&2
          exit 75
        fi
        ;;
    esac

    case "$command" in
      up)
        ensure_base_dir
        ensure_current_conf
        render_runtime_conf
        ks_enable
        mss_enable
        restart_and_check
        "$SYSTEMCTL" --no-pager --full status "$WG_UNIT"
        ;;
      down)
        "$SYSTEMCTL" stop "$WG_UNIT"
        mss_disable
        ks_disable
        ;;
      switch)
        if [[ $# -lt 2 || ! "$2" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
          echo "Usage: mullvad-gw switch <server-name>" >&2
          exit 1
        fi
        target="$SERVER_DIR/$2.conf"
        if [[ ! -r "$target" ]]; then
          echo "Unknown server '$2' (expected: $target)" >&2
          exit 1
        fi
        selected_country="''${2%%-*}"
        if [[ ! "$selected_country" =~ ^[a-z]{2}$ ]]; then
          echo "Server '$2' does not begin with a valid two-letter country code" >&2
          exit 1
        fi
        ${pkgs.coreutils}/bin/ln -s "$target" "$BASE_DIR/.current.$$"
        ${pkgs.coreutils}/bin/mv -Tf "$BASE_DIR/.current.$$" "$CURRENT_LINK"
        printf '%s\n' "$selected_country" > "$BASE_DIR/.country.$$"
        ${pkgs.coreutils}/bin/chmod 0600 "$BASE_DIR/.country.$$"
        ${pkgs.coreutils}/bin/mv -f "$BASE_DIR/.country.$$" "$COUNTRY_FILE"
        render_runtime_conf
        if "$SYSTEMCTL" is-active --quiet "$WG_UNIT"; then
          ks_enable
          mss_enable
          restart_and_check
        fi
        ;;
      refresh)
        refresh_profiles
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
          real_file="$(${pkgs.coreutils}/bin/readlink -f "$file" 2>/dev/null || true)"
          [[ "$real_file" == "$current" ]] && marker="*"
          printf "%s %s\n" "$marker" "$name"
        done
        ;;
      status)
        if "$SYSTEMCTL" is-active --quiet "$WG_UNIT"; then
          echo "mullvad: up"
          if check_health; then
            echo "health: handshake and traffic OK"
          else
            echo "health: handshake/traffic FAILED"
          fi
        else
          echo "mullvad: down"
        fi
        ks_rule_exists && echo "killswitch: enabled" || echo "killswitch: disabled"
        mss_rule_exists && echo "mss-clamp: enabled" || echo "mss-clamp: disabled"
        [[ -e "$CURRENT_LINK" ]] && echo "current config: $(${pkgs.coreutils}/bin/readlink -f "$CURRENT_LINK")" || echo "current config: missing ($CURRENT_LINK)"
        [[ -e "$RUNTIME_CONF" ]] && echo "runtime config: $RUNTIME_CONF" || echo "runtime config: missing ($RUNTIME_CONF)"
        if ${pkgs.iproute2}/bin/ip link show "$WG_IF" >/dev/null 2>&1; then
          ${pkgs.wireguard-tools}/bin/wg show "$WG_IF" || true
        fi
        ;;
      *)
        echo "Usage: mullvad-gw <up|down|status|list|refresh|switch SERVER>" >&2
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

  environment.systemPackages = [ mullvadGatewayScript ];

  systemd.services.mullvad-relay-refresh = {
    description = "Refresh Mullvad WireGuard relay profiles";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${mullvadGatewayScript}/bin/mullvad-gw refresh";
      TimeoutStartSec = "3min";
      Restart = "on-failure";
      RestartSec = "15min";
    };
    startLimitIntervalSec = 7200;
    startLimitBurst = 3;
  };

  systemd.timers.mullvad-relay-refresh = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnCalendar = "daily";
      Persistent = true;
      Unit = "mullvad-relay-refresh.service";
    };
  };
}
