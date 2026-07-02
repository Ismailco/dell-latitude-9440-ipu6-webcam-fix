#!/usr/bin/env bash
set -euo pipefail

device=${VIRTUALCAM_DEVICE:-/dev/video42}
width=${VIRTUALCAM_WIDTH:-1280}
height=${VIRTUALCAM_HEIGHT:-720}
framerate=${VIRTUALCAM_FRAMERATE:-30/1}
format=${VIRTUALCAM_FORMAT:-YUY2}
idle_delay=${VIRTUALCAM_IDLE_DELAY:-10}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$1" >&2
    exit 127
  fi
}

require_command gst-launch-1.0
require_command fuser

if ! [[ -e "$device" ]]; then
  printf 'missing %s; run scripts/install.sh and check v4l2loopback\n' "$device" >&2
  exit 1
fi

printf 'Testing direct libcamera path...\n'
timeout 15 gst-launch-1.0 -q libcamerasrc ! \
  video/x-raw,width="${width}",height="${height}",framerate="${framerate}" ! \
  fakesink num-buffers=30

printf 'Testing virtual camera path through %s...\n' "$device"
timeout 15 gst-launch-1.0 -q v4l2src device="$device" num-buffers=120 ! \
  video/x-raw,format="${format}",width="${width}",height="${height}",framerate="${framerate}" ! \
  fakesink

idle_wait=$(awk -v delay="$idle_delay" 'BEGIN { printf "%.3f", delay + 3 }')
sleep "$idle_wait"

printf 'Current device users after %s seconds idle wait:\n' "$idle_wait"
fuser -v "$device" /dev/video0 /dev/media0 || true

printf 'Camera test passed.\n'
