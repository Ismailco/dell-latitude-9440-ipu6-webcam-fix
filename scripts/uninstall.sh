#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=scripts/common.sh
source "$script_dir/common.sh"

remove_loopback_config=0

usage() {
  cat <<'USAGE'
Usage: scripts/uninstall.sh [options]

Options:
  --remove-loopback-config  Remove /etc v4l2loopback config if it matches this repo.
  -h, --help                Show this help.
USAGE
}

while (($#)); do
  case "$1" in
    --remove-loopback-config)
      remove_loopback_config=1
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

systemctl --user disable --now virtualcam.service >/dev/null 2>&1 || true
rm -f "$HOME/.config/systemd/user/virtualcam.service"
rm -f "$HOME/.local/bin/start-virtualcam"
systemctl --user daemon-reload

if (( remove_loopback_config )); then
  if cmp -s "$root/modprobe.d/v4l2loopback.conf" /etc/modprobe.d/v4l2loopback.conf; then
    sudo_cmd rm -f /etc/modprobe.d/v4l2loopback.conf
  else
    printf 'preserving /etc/modprobe.d/v4l2loopback.conf: content differs\n' >&2
  fi

  if cmp -s "$root/modules-load.d/v4l2loopback.conf" /etc/modules-load.d/v4l2loopback.conf; then
    sudo_cmd rm -f /etc/modules-load.d/v4l2loopback.conf
  else
    printf 'preserving /etc/modules-load.d/v4l2loopback.conf: content differs\n' >&2
  fi
fi

printf 'Uninstalled user virtualcam service.\n'

