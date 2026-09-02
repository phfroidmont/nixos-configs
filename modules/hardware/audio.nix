{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.modules.hardware.audio;
  voxtypePackage = pkgs.voxtype.override { vulkanSupport = true; };
  voxtypeModel = pkgs.fetchurl {
    name = "ggml-base.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin";
    hash = "sha256-YO1bw90U7qhWST0zQ0m0BXgt3K8AKNS130CINF+6Lv4=";
  };
  voxtypeConfig = (pkgs.formats.toml { }).generate "voxtype-config.toml" {
    state_file = "auto";
    hotkey.enabled = false;
    audio = {
      device = "default";
      sample_rate = 16000;
      max_duration_secs = 60;
      pause_media = true;
    };
    whisper = {
      model = toString voxtypeModel;
      language = "auto";
      translate = false;
      flash_attention = true;
    };
    output = {
      mode = "type";
      fallback_to_clipboard = true;
      type_delay_ms = 1;
      notification = {
        on_recording_start = false;
        on_recording_stop = false;
        on_transcription = false;
      };
    };
    osd.enabled = false;
  };
in
{
  options.modules.hardware.audio = {
    enable = lib.my.mkBoolOpt false;
  };

  config = lib.mkIf cfg.enable {

    security.rtkit.enable = true;

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    home-manager.users.${config.user.name} = {
      home.packages = [
        pkgs.pulsemixer
        voxtypePackage
      ];

      xdg.configFile."voxtype/config.toml".source = voxtypeConfig;

      systemd.user.services.voxtype = {
        Unit = {
          Description = "Voxtype push-to-talk voice-to-text daemon";
          After = [
            "graphical-session.target"
            "pipewire.service"
            "pipewire-pulse.service"
          ];
          PartOf = [ "graphical-session.target" ];
          X-Restart-Triggers = [
            voxtypeConfig
            voxtypeModel
          ];
        };
        Service = {
          ExecStart = "${lib.getExe voxtypePackage} -q daemon";
          Restart = "on-failure";
          RestartSec = 5;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
