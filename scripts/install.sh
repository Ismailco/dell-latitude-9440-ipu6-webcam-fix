#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$script_dir/common.sh"

force=0
enable_service=1
disable_v4l2_relayd=1

usage() {
  cat <<'USAGE'
Usage: scripts/install.sh [options]

Options:
  --force              Install even if this is not detected as Latitude 9440.
  --no-enable          Install files but do not enable/start the user service.
  --keep-v4l2-relayd   Do not disable the packaged v4l2-relayd service.
  -h, --help           Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    --force)
      force=1
      ;;
    --no-enable)
      enable_service=0
      ;;
    --keep-v4l2-relayd)
      disable_v4l2_relayd=0
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

root=$(repo_root)

if (( ! force )) && ! is_latitude_9440; then
  printf 'Refusing install: detected model is "%s"\n' "$(print_model)" >&2
  printf 'Pass --force if you intentionally want to install anyway.\n' >&2
  exit 1
fi

require_command install
require_command systemctl
require_command gst-launch-1.0
require_command fuser
require_command v4l2-ctl

install -Dm755 "$root/bin/start-virtualcam" "$HOME/.local/bin/start-virtualcam"
install -Dm644 "$root/systemd/user/virtualcam.service" \
  "$HOME/.config/systemd/user/virtualcam.service"

sudo_cmd install -Dm644 "$root/modprobe.d/v4l2loopback.conf" \
  /etc/modprobe.d/v4l2loopback.conf
sudo_cmd install -Dm644 "$root/modules-load.d/v4l2loopback.conf" \
  /etc/modules-load.d/v4l2loopback.conf

if (( disable_v4l2_relayd )) && systemctl list-unit-files v4l2-relayd.service \
  >/dev/null 2>&1; then
  sudo_cmd systemctl disable --now v4l2-relayd.service >/dev/null 2>&1 || true
  sudo_cmd systemctl stop v4l2-relayd@virtualcam.service >/dev/null 2>&1 || true
fi

if ! [[ -e /dev/video42 ]]; then
  sudo_cmd modprobe v4l2loopback || true
fi

systemctl --user daemon-reload

if (( enable_service )); then
  systemctl --user enable --now virtualcam.service
fi

cat <<'DONE'
Installed Dell Latitude 9440 virtual webcam bridge.

Next:
  ./scripts/doctor.sh
  ./scripts/test-camera.sh
DONE
