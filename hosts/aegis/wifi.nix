{
  lib,
  pkgs,
  ...
}:
let
  lanBridge = "br-lan";
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
in
{
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
}
