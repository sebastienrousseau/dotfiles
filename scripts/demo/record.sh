#!/bin/sh
set -e

OUT="${1:-$HOME/.dotfiles/docs/demo/demo.gif}"
DURATION="${DURATION:-30}"
FPS="${FPS:-15}"

record_ffmpeg() {
  if command -v ffmpeg >/dev/null; then
    echo "Recording with ffmpeg for ${DURATION}s..."
    if [ "$(uname -s)" = "Darwin" ]; then
      # macOS (AVFoundation)
      ffmpeg -y -t "$DURATION" -f avfoundation -i "1:none" -vf "fps=$FPS,scale=1024:-1:flags=lanczos" "$OUT"
    else
      # Linux (X11)
      ffmpeg -y -t "$DURATION" -f x11grab -i :0.0 -vf "fps=$FPS,scale=1024:-1:flags=lanczos" "$OUT"
    fi
  else
    echo "ffmpeg not found. Install it and retry."
    exit 1
  fi
}

record_wf_recorder() {
  if command -v wf-recorder >/dev/null; then
    echo "Recording with wf-recorder for ${DURATION}s..."
    wf-recorder -f "$OUT" -t "$DURATION"
  else
    return 1
  fi
}

if [ "$(uname -s)" = "Linux" ]; then
  if record_wf_recorder; then
    exit 0
  fi
fi

record_ffmpeg

printf "Saved demo to %s\n" "$OUT"
