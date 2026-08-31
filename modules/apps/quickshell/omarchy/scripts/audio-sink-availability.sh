set -euo pipefail

(( $# == 0 )) || { echo "Usage: fos-internal-audio-sink-availability" >&2; exit 2; }
pactl list sinks | awk '
  function emit() { if (name != "") print name "\t" ((ports == 0 || available) ? 1 : 0) }
  /^Sink #/ { emit(); name = ""; in_ports = 0; ports = 0; available = 0; next }
  /^[[:space:]]*Name:/ { name = $2; next }
  /^[[:space:]]*Ports:$/ { in_ports = 1; next }
  in_ports && /^\tActive Port:/ { in_ports = 0; next }
  in_ports && /^\t\t/ { ports++; if ($0 !~ /not available/) available = 1 }
  END { emit() }
'
