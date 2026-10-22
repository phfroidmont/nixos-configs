# Transcribes a meeting recording into a text file next to it.
#
# Expects whisper_model, vad_model, whisper_device, segmentation_model, and
# embedding_model to be set by the Nix wrapper. The recording's left channel is
# the microphone and its right one the meeting's audio output.

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

# whisper.cpp reads 16 kHz WAV and compares both channels to tell which one a
# segment was heard on. Speaker diarization reads one channel at a time, as
# plain mono WAV: it rejects the extended header of a split stereo channel.
ffmpeg -hide_banner -nostdin -loglevel error -i "$recording" \
  -ar 16000 -ac 2 -c:a pcm_s16le "$work_dir/audio.wav"
ffmpeg -hide_banner -nostdin -loglevel error -i "$work_dir/audio.wav" \
  -af 'pan=mono|c0=c0' "$work_dir/left.wav" \
  -af 'pan=mono|c0=c1' "$work_dir/right.wav"

# VAD skips silences, where Whisper otherwise invents text and loses track.
# Short segments rarely span two speakers.
whisper-cli \
  --model "$whisper_model" \
  --device "$whisper_device" \
  --vad --vad-model "$vad_model" \
  --language auto \
  --diarize \
  --max-len 80 --split-on-word \
  --no-prints \
  --output-json --output-file "$work_dir/transcript" \
  --file "$work_dir/audio.wav" >/dev/null

# Each channel is diarized on its own: in a meeting room, the microphone hears
# everyone and the output plays the same voices back later, which mixed
# together would blur the voices. A cluster threshold of 0.5 separated three
# people talking in a room into three speakers; 0.7 merged them into one.
# More than 8 threads is slower and burns far more CPU time.
threads=$(nproc)
if ((threads > 8)); then
  threads=8
fi
for channel in left right; do
  printf 'Diarizing the %s channel\n' "$channel"
  sherpa-onnx-offline-speaker-diarization \
    --segmentation.pyannote-model="$segmentation_model" \
    --embedding.model="$embedding_model" \
    --clustering.cluster-threshold=0.5 \
    --segmentation.num-threads="$threads" \
    --embedding.num-threads="$threads" \
    "$work_dir/$channel.wav" >"$work_dir/$channel-turns.txt"
done

# Give each segment to the speaker who talks the most during it on the channel
# Whisper heard it on, number speakers by first appearance, and merge
# consecutive segments of the same speaker into one timestamped paragraph.
# shellcheck disable=SC2016
jq -r \
  --rawfile left_turns "$work_dir/left-turns.txt" \
  --rawfile right_turns "$work_dir/right-turns.txt" '
  # Diarization prints lines such as "1.398 -- 15.809 speaker_00".
  def turns:
    split("\n")
    | map(capture("^(?<start>[0-9.]+) -- (?<end>[0-9.]+) (?<speaker>speaker_[0-9]+)$")
      | {start: (.start | tonumber), end: (.end | tonumber), speaker});

  def overlap($from; $to):
    [([$to, .end] | min) - ([$from, .start] | max), 0] | max;

  def speaker_key($turns; $channel):
    (.offsets.from / 1000) as $from
    | (.offsets.to / 1000) as $to
    | [$turns[] | {speaker, overlap: overlap($from; $to)} | select(.overlap > 0)]
    | if length == 0 then null else "\($channel):\(max_by(.overlap).speaker)" end;

  ($left_turns | turns) as $left
  | ($right_turns | turns) as $right
  | [.transcription[]
      | select((.text | gsub("\\s"; "")) != "")
      | {
          start: (.timestamps.from | split(",")[0]),
          key: (if .speaker == "1" then speaker_key($right; "right") else speaker_key($left; "left") end),
          text: (.text | sub("^\\s+"; ""))
        }]
  | (reduce (.[].key | select(. != null)) as $key ([];
      if index([$key]) then . else . + [$key] end)) as $speaker_keys
  | reduce .[] as $segment ([];
      ($segment.key
        | if . == null then "Unclear" else "Speaker \($speaker_keys | index([$segment.key]) + 1)" end
      ) as $speaker
      | if length > 0 and .[-1].speaker == $speaker then
          .[-1].text += " " + $segment.text
        else
          . + [{start: $segment.start, speaker: $speaker, text: $segment.text}]
        end)
  | .[]
  | "[\(.start)] \(.speaker): \(.text)\n"
' "$work_dir/transcript.json" >"$work_dir/transcript.txt"

mv -f -- "$work_dir/transcript.txt" "$transcript"
printf 'Wrote %s in %ss\n' "$transcript" "$((SECONDS - started))"
notify-send --app-name='Meeting recording' 'Meeting transcript ready' "$transcript" || true
