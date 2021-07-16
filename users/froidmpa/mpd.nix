{ config, ... }:
{
  enable = true;
  network.listenAddress = "any";
  musicDirectory = "${config.home.homeDirectory}/Nextcloud/Media/Music";
  playlistDirectory = "${config.home.homeDirectory}/Nextcloud/Playlists";
  extraConfig = ''
    max_output_buffer_size "16384"
    auto_update "yes"
    audio_output {
        type  "pulse"
        name  "pulse audio"
        device         "pulse"
        mixer_type      "hardware"
    }
    audio_output {
        type            "fifo"
        name            "toggle_visualizer"
        path            "/tmp/mpd.fifo"
        format          "44100:16:2"
    }
  '';
}
