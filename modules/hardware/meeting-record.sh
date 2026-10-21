# Records a meeting until stopped, then queues its transcription.
#
# The default microphone goes to the left channel and the default output's
# monitor to the right one, so the transcription can tell "Me" from "Others".

output_dir=$HOME/Recordings/meetings
mkdir -p -- "$output_dir"
output=$output_dir/meeting-$(date +%Y-%m-%d_%H-%M-%S).opus

printf 'Recording meeting to %s\n' "$output"
notify-send --app-name='Meeting recording' 'Recording meeting' "$output" || true

ffmpeg -hide_banner -nostdin -loglevel warning \
  -f pulse -name meeting-recording-microphone -channels 1 -i default \
  -f pulse -name meeting-recording-output -channels 1 -i @DEFAULT_MONITOR@ \
  -filter_complex '[0:a][1:a]join=inputs=2:channel_layout=stereo:map=0.0-FL|1.0-FR[meeting]' \
  -map '[meeting]' -c:a libopus -b:a 48k -application voip \
  "$output" &
ffmpeg_pid=$!

# systemd only signals this script (KillMode=mixed). Forward the stop request so
# ffmpeg finalizes the file, then keep running to queue the transcription.
trap 'kill -TERM "$ffmpeg_pid" 2>/dev/null || true' INT TERM
ffmpeg_status=0
wait "$ffmpeg_pid" || ffmpeg_status=$?
if ((ffmpeg_status > 128)) && kill -0 "$ffmpeg_pid" 2>/dev/null; then
  ffmpeg_status=0
  wait "$ffmpeg_pid" || ffmpeg_status=$?
fi
trap - INT TERM

# ffmpeg exits with 255 after a requested stop.
if ((ffmpeg_status != 0 && ffmpeg_status != 255)); then
  printf 'ffmpeg exited with status %s\n' "$ffmpeg_status" >&2
fi

if [[ ! -s $output ]]; then
  printf 'No audio was recorded to %s\n' "$output" >&2
  rm -f -- "$output"
  notify-send --app-name='Meeting recording' --urgency=critical 'Meeting recording failed' \
    'No audio was recorded; see journalctl --user -u meeting-recording' || true
  exit 1
fi

transcription_unit="meeting-transcription@$(systemd-escape --path -- "$output").service"
printf 'Queueing %s\n' "$transcription_unit"
systemctl --user start --no-block "$transcription_unit"
notify-send --app-name='Meeting recording' 'Meeting recording saved' "Transcribing $output" || true
