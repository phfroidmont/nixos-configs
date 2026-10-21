# Transcribes a meeting recording into a text file next to it.
#
# Expects whisper_model, vad_model, and whisper_device to be set by the Nix
# wrapper. The recording's left channel is "Me" and its right one "Others".

if (($# != 1)); then
  printf 'usage: meeting-transcribe RECORDING\n' >&2
  exit 2
fi
recording=$1
transcript=${recording%.*}.txt
if [[ ! -f $recording ]]; then
  printf 'Recording not found: %s\n' "$recording" >&2
  exit 1
fi

notify_failure() {
  notify-send --app-name='Meeting recording' --urgency=critical 'Meeting transcription failed' \
    "$recording"$'\n''See journalctl --user -u "meeting-transcription@*"' || true
}
trap notify_failure ERR

work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT

printf 'Transcribing %s\n' "$recording"
started=$SECONDS

# whisper.cpp reads 16 kHz WAV; keep both channels for the Me/Others split.
ffmpeg -hide_banner -nostdin -loglevel error -i "$recording" \
  -ar 16000 -ac 2 -c:a pcm_s16le "$work_dir/audio.wav"

# VAD skips silences, where Whisper otherwise invents text and loses track.
whisper-cli \
  --model "$whisper_model" \
  --device "$whisper_device" \
  --vad --vad-model "$vad_model" \
  --language auto \
  --diarize \
  --no-prints \
  --output-json --output-file "$work_dir/transcript" \
  --file "$work_dir/audio.wav" >/dev/null

# Merge consecutive segments of the same speaker into one timestamped paragraph.
# shellcheck disable=SC2016
jq -r '
  def speaker_name:
    if . == "0" then "Me" elif . == "1" then "Others" else "Unclear" end;

  reduce (.transcription[] | select((.text | gsub("\\s"; "")) != "")) as $segment ([];
    ($segment.speaker | speaker_name) as $speaker
    | ($segment.text | sub("^\\s+"; "")) as $text
    | if length > 0 and .[-1].speaker == $speaker then
        .[-1].text += " " + $text
      else
        . + [{
          start: ($segment.timestamps.from | split(",")[0]),
          speaker: $speaker,
          text: $text
        }]
      end)
  | .[]
  | "[\(.start)] \(.speaker): \(.text)\n"
' "$work_dir/transcript.json" >"$work_dir/transcript.txt"

mv -f -- "$work_dir/transcript.txt" "$transcript"
printf 'Wrote %s in %ss\n' "$transcript" "$((SECONDS - started))"
notify-send --app-name='Meeting recording' 'Meeting transcript ready' "$transcript" || true
