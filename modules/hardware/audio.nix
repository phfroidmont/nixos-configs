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

  whisperPackage = pkgs.whisper-cpp.override { vulkanSupport = true; };
  meetingWhisperModel = pkgs.fetchurl {
    name = "ggml-large-v3-turbo-q8_0.bin";
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q8_0.bin";
    hash = "sha256-MX62nBFnPJ3h4fDUWbJTmZgE7HGsTCPBfs9fviTiWaE=";
  };
  meetingVadModel = pkgs.fetchurl {
    name = "ggml-silero-v5.1.2.bin";
    url = "https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v5.1.2.bin";
    hash = "sha256-KZQNmNQrkfvQXOSJ8+z3xy8KQvAn5IdZGaKPtMBOos8=";
  };
  meetingSegmentationModel = pkgs.fetchzip {
    name = "sherpa-onnx-pyannote-segmentation-3-0";
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-segmentation-models/sherpa-onnx-pyannote-segmentation-3-0.tar.bz2";
    hash = "sha256-hqaCTZJKZp6IHxYzgVBd9Bss6wC1qg+edB/v10BT1tA=";
  };
  meetingEmbeddingModel = pkgs.fetchurl {
    name = "wespeaker_en_voxceleb_resnet34_LM.onnx";
    url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/speaker-recongition-models/wespeaker_en_voxceleb_resnet34_LM.onnx";
    hash = "sha256-6YSFY9qG8mMRcTTf161jySNVs33kkrVeMlQAydnDkBI=";
  };
  meetingRecord = pkgs.writeShellApplication {
    name = "meeting-record";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ffmpeg
      pkgs.libnotify
      pkgs.systemd
    ];
    text = builtins.readFile ./meeting-record.sh;
  };
  meetingTranscribe = pkgs.writeShellApplication {
    name = "meeting-transcribe";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.ffmpeg
      pkgs.jq
      pkgs.libnotify
      pkgs.sherpa-onnx
      whisperPackage
    ];
    text = ''
      whisper_model=${meetingWhisperModel}
      vad_model=${meetingVadModel}
      whisper_device=${toString cfg.meetingTranscriptionDevice}
      segmentation_model=${meetingSegmentationModel}/model.onnx
      embedding_model=${meetingEmbeddingModel}
    ''
    + builtins.readFile ./meeting-transcribe.sh;
  };
in
{
  options.modules.hardware.audio = {
    enable = lib.mkEnableOption "audio";
    meetingTranscriptionDevice = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 0;
      description = "Vulkan device index whisper.cpp uses to transcribe meetings.";
    };
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

      systemd.user.services.meeting-recording = {
        Unit = {
          Description = "Meeting audio recording";
          After = [ "pipewire-pulse.service" ];
        };
        Service = {
          ExecStart = lib.getExe meetingRecord;
          # Signal only the script, which stops ffmpeg cleanly and then queues
          # the transcription.
          KillMode = "mixed";
          TimeoutStopSec = 30;
        };
      };

      systemd.user.services."meeting-transcription@" = {
        Unit.Description = "Meeting transcription of %f";
        Service = {
          Type = "oneshot";
          ExecStart = "${lib.getExe meetingTranscribe} %f";
          Nice = 10;
        };
      };
    };
  };
}
